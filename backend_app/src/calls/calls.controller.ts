import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { AgoraTokenService } from './services/agora-token.service';
import { TokenRequestDto } from './dto/token-request.dto';
import { TokenResponseDto } from './dto/token-response.dto';

/** Request with Firebase-decoded user (set by FirebaseAuthGuard). */
interface RequestWithUser extends Request {
  user: { uid: string; [k: string]: unknown };
}

/**
 * Calls API
 * Provides Agora RTC tokens for calling and live audio streaming.
 * All endpoints require Firebase ID token in Authorization: Bearer <token>.
 */
@Controller('calls')
@UseGuards(FirebaseAuthGuard)
export class CallsController {
  constructor(private readonly agoraTokenService: AgoraTokenService) {}

  /**
   * Get an Agora RTC token to join a channel.
   * POST /calls/token
   * Body: { channelName: string, uid?: number, role?: 'publisher' | 'subscriber' }
   */
  @Post('token')
  async getToken(
    @Req() req: RequestWithUser,
    @Body() dto: TokenRequestDto,
  ): Promise<TokenResponseDto> {
    const firebaseUid = req.user?.uid ?? 'anonymous';
    const uid = dto.uid ?? this.uidFromFirebaseUid(firebaseUid);
    return this.agoraTokenService.generateRtcToken(
      dto.channelName,
      uid,
      dto.role ?? 'publisher',
    );
  }

  /**
   * Get Agora App ID only (e.g. for client config before joining).
   * GET /calls/config
   */
  @Get('config')
  getConfig(): { appId: string } {
    return { appId: this.agoraTokenService.getAppId() };
  }

  /** Generate a numeric uid in Agora range from a string (e.g. Firebase uid). */
  private uidFromFirebaseUid(firebaseUid: string): number {
    let hash = 0;
    for (let i = 0; i < firebaseUid.length; i++) {
      const c = firebaseUid.charCodeAt(i);
      hash = (hash << 5) - hash + c;
      hash = hash & 0x7fffffff;
    }
    return Math.max(1, hash) % (2 ** 32 - 1);
  }
}
