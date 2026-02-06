import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Reel } from './entities/reel.entity';
import { ReelResponseDto } from './dto/reel-response.dto';

/** Seed reels when table is empty (replace URLs with Firebase Storage for production) */
const SEED_AUDIO_URL = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
const SEED_REELS: Array<{ title: string; imageUrl: string; audioUrl: string; durationSeconds: number; sortOrder: number }> = [
  { title: 'Sample Reel 1', imageUrl: 'https://picsum.photos/seed/reel1/800/1200', audioUrl: SEED_AUDIO_URL, durationSeconds: 60, sortOrder: 0 },
  { title: 'Sample Reel 2', imageUrl: 'https://picsum.photos/seed/reel2/800/1200', audioUrl: SEED_AUDIO_URL, durationSeconds: 60, sortOrder: 1 },
  { title: 'Sample Reel 3', imageUrl: 'https://picsum.photos/seed/reel3/800/1200', audioUrl: SEED_AUDIO_URL, durationSeconds: 60, sortOrder: 2 },
  { title: 'Sample Reel 4', imageUrl: 'https://picsum.photos/seed/reel4/800/1200', audioUrl: SEED_AUDIO_URL, durationSeconds: 60, sortOrder: 3 },
  { title: 'Sample Reel 5', imageUrl: 'https://picsum.photos/seed/reel5/800/1200', audioUrl: SEED_AUDIO_URL, durationSeconds: 60, sortOrder: 4 },
];

/**
 * Reels Service
 * Fetches reel metadata from the database.
 * Media (audio/image) is served from stored URLs (e.g. Firebase Storage).
 */
@Injectable()
export class ReelsService implements OnModuleInit {
  constructor(
    @InjectRepository(Reel)
    private readonly reelRepository: Repository<Reel>,
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
   * Get all reels ordered by sortOrder then createdAt.
   * Returns DTOs with ISO date strings for client consistency.
   */
  async findAll(): Promise<ReelResponseDto[]> {
    const reels = await this.reelRepository.find({
      order: { sortOrder: 'ASC', createdAt: 'ASC' },
    });
    return reels.map((reel) => this.toResponseDto(reel));
  }

  private toResponseDto(reel: Reel): ReelResponseDto {
    return {
      id: reel.id,
      title: reel.title,
      audioUrl: reel.audioUrl,
      imageUrl: reel.imageUrl,
      durationSeconds: reel.durationSeconds,
      sortOrder: reel.sortOrder,
      createdAt: reel.createdAt.toISOString(),
    };
  }
}
