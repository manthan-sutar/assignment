import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { LiveService } from './services/live.service';
import { StartLiveResponseDto } from './dto/start-live-response.dto';
import { LiveSessionDto } from './dto/live-session.dto';

interface RequestWithUser extends Request {
  user: { uid: string; [k: string]: unknown };
}

@Controller('live')
@UseGuards(FirebaseAuthGuard)
export class LiveController {
  constructor(private readonly liveService: LiveService) {}

  /**
   * Start a live stream. Returns Agora token and channel info for the host (publisher).
   * POST /live/start
   */
  @Post('start')
  async startLive(@Req() req: RequestWithUser): Promise<StartLiveResponseDto> {
    const hostUid = req.user?.uid ?? '';
    return this.liveService.startLive(hostUid);
  }

  /**
   * Get a new host token for your current live session (re-enter host screen).
   * GET /live/host-token
   */
  @Get('host-token')
  getHostToken(@Req() req: RequestWithUser): StartLiveResponseDto {
    const hostUid = req.user?.uid ?? '';
    const result = this.liveService.getHostToken(hostUid);
    if (!result) {
      throw new NotFoundException('You are not live');
    }
    return result;
  }

  /**
   * End your current live stream.
   * POST /live/end
   */
  @Post('end')
  async endLive(@Req() req: RequestWithUser): Promise<{ sessionId: string }> {
    const hostUid = req.user?.uid ?? '';
    return this.liveService.endLive(hostUid);
  }

  /**
   * List all active live streams (for dashboard). No auth required for discovery?
   * We keep auth so only logged-in users see the list.
   * GET /live/sessions
   */
  @Get('sessions')
  getSessions(): LiveSessionDto[] {
    return this.liveService.getSessions();
  }
}
