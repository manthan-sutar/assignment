import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { randomUUID } from 'crypto';
import { Reel } from './entities/reel.entity';
import { ReelResponseDto } from './dto/reel-response.dto';
import { FirebaseService } from '../common/services/firebase.service';

/** Seed reels when table is empty (Firebase Storage URLs) */
const SEED_REELS: Array<{
  title: string;
  description: string | null;
  imageUrl: string | null;
  audioUrl: string;
  durationSeconds: number;
  sortOrder: number;
}> = [
  {
    title: 'A one minute TEDx Talk for the digital age',
    description: 'Woody Roseland | TEDxMileHigh',
    imageUrl: null,
    audioUrl:
      'https://firebasestorage.googleapis.com/v0/b/audioreel.firebasestorage.app/o/reels%2Faudio%2FA%20one%20minute%20TEDx%20Talk%20for%20the%20digital%20age%20_%20Woody%20Roseland%20_%20TEDxMileHigh.m4a?alt=media&token=7d1f44fe-24ef-48c4-9066-81c48d506e8d',
    durationSeconds: 60,
    sortOrder: 0,
  },
  {
    title: '1 Minute Podcast Introduction',
    description: null,
    imageUrl: null,
    audioUrl:
      'https://firebasestorage.googleapis.com/v0/b/audioreel.firebasestorage.app/o/reels%2Faudio%2F1%20Minute%20Podcast%20Introduction.m4a?alt=media&token=2f0ca32f-9f89-4465-970f-a0498012e55b',
    durationSeconds: 60,
    sortOrder: 1,
  },
];

/**
 * Reels Service
 * Fetches reel metadata from the database.
 * Media (audio/image) is served from stored URLs (e.g. Firebase Storage).
 */
/** Supported audio extensions for ffmpeg input */
const AUDIO_EXT = /\.(mp3|wav|m4a|aac|ogg|flac|webm)$/i;

@Injectable()
export class ReelsService implements OnModuleInit {
  constructor(
    @InjectRepository(Reel)
    private readonly reelRepository: Repository<Reel>,
    private readonly firebaseService: FirebaseService,
  ) {}

  async onModuleInit(): Promise<void> {
    const count = await this.reelRepository.count();
    if (count === 0) {
      await this.reelRepository.save(
        SEED_REELS.map((seed) => this.reelRepository.create(seed)),
      );
    }
  }

  /**
   * Create a reel from an uploaded audio file.
   * Converts to M4A (AAC, fast start), uploads to Firebase Storage, saves metadata to DB.
   * Requires ffmpeg and ffprobe on the server.
   */
  async createFromUpload(
    file: { buffer: Buffer; originalname?: string },
    title: string,
    description?: string | null,
  ): Promise<ReelResponseDto> {
    const ext = file.originalname?.match(AUDIO_EXT)?.[1] ?? 'mp3';
    const id = randomUUID();
    const tmpDir = os.tmpdir();
    const inputPath = path.join(tmpDir, `reel-in-${id}.${ext}`);
    const outputPath = path.join(tmpDir, `reel-out-${id}.m4a`);
    try {
      fs.writeFileSync(inputPath, file.buffer);
      execSync(
        `ffmpeg -i "${inputPath}" -vn -c:a aac -movflags +faststart -b:a 128k -y "${outputPath}"`,
        { stdio: 'pipe' },
      );
      const durationOut = execSync(
        `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${outputPath}"`,
        { encoding: 'utf-8' },
      );
      const durationSeconds = Math.ceil(
        Number.parseFloat(String(durationOut).trim()) || 0,
      );
      const m4aBuffer = fs.readFileSync(outputPath);
      const storagePath = `reels/audio/${id}.m4a`;
      /* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call */
      const audioUrl = await this.firebaseService.uploadBufferAndGetUrl(
        storagePath,
        m4aBuffer,
        'audio/mp4',
      );
      /* eslint-enable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call */
      const [last] = await this.reelRepository.find({
        order: { sortOrder: 'DESC' },
        take: 1,
      });
      const nextSortOrder: number = (last?.sortOrder ?? -1) + 1;
      const reel = this.reelRepository.create({
        title,
        description: description ?? null,
        audioUrl: audioUrl as string,
        imageUrl: null,
        durationSeconds,
        sortOrder: nextSortOrder,
      });
      const saved = await this.reelRepository.save(reel);
      return this.toResponseDto(saved);
    } finally {
      try {
        if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
      } catch {
        // ignore cleanup errors
      }
    }
  }

  /**
   * Get all reels ordered by sortOrder then createdAt.
   * Returns DTOs with ISO date strings for client consistency.
   */
  async findAll(): Promise<ReelResponseDto[]> {
    const reels = await this.reelRepository.find({
      order: { sortOrder: 'ASC', createdAt: 'ASC' },
    });
    return reels.map((reel: Reel) => this.toResponseDto(reel));
  }

  private toResponseDto(reel: Reel): ReelResponseDto {
    return {
      id: reel.id,
      title: reel.title,
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment -- entity columns
      description: reel.description ?? null,
      audioUrl: reel.audioUrl,
      imageUrl: reel.imageUrl ?? null,
      durationSeconds: reel.durationSeconds,
      sortOrder: reel.sortOrder,
      createdAt: reel.createdAt.toISOString(),
    };
  }
}
