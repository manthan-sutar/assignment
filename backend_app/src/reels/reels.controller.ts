import { Controller, Get, UseGuards } from '@nestjs/common';
import { ReelsService } from './reels.service';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';

/**
 * Reels Controller
 * Serves audio reels metadata for consumption-only feed.
 * GET /reels - List reels (protected)
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
}
