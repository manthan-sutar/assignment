import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ReelsService } from './reels.service';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { AdminGuard } from './guards/admin.guard';

/**
 * Reels Controller
 * Serves audio reels metadata for consumption-only feed.
 * GET /reels - List reels (protected)
 * POST /reels/admin - Upload reel (admin key required)
 */
@Controller('reels')
export class ReelsController {
  constructor(private readonly reelsService: ReelsService) {}

  /**
   * List all reels
   * GET /reels
   * Requires valid Firebase ID token in Authorization: Bearer <token>
   */
  @UseGuards(FirebaseAuthGuard)
  @Get()
  async list() {
    return this.reelsService.findAll();
  }

  /**
   * Upload a new reel (title, description, audio file).
   * Converts audio to M4A and stores in Firebase Storage.
   * Header: X-Admin-Key = ADMIN_API_KEY
   */
  @UseGuards(AdminGuard)
  @Post('admin')
  @UseInterceptors(
    FileInterceptor('audio', {
      storage: memoryStorage(),
      limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
    }),
  )
  async uploadReel(
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body('title') title: string,
    @Body('description') description?: string,
  ) {
    if (!file?.buffer) {
      throw new BadRequestException('Missing audio file');
    }
    const t = typeof title === 'string' ? title.trim() : '';
    if (!t) {
      throw new BadRequestException('Title is required');
    }
    return this.reelsService.createFromUpload(
      { buffer: file.buffer, originalname: file.originalname },
      t,
      typeof description === 'string' ? description.trim() || null : null,
    );
  }
}
