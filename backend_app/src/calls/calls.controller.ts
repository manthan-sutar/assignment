import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { AgoraTokenService } from './services/agora-token.service';
import { CallOfferService } from './services/call-offer.service';
import { TokenRequestDto } from './dto/token-request.dto';
import { TokenResponseDto } from './dto/token-response.dto';
import { CreateOfferDto } from './dto/create-offer.dto';
import {
  CreateOfferResponseDto,
  AcceptOfferResponseDto,
} from './dto/offer-response.dto';

/** Request with Firebase-decoded user (set by FirebaseAuthGuard). */
interface RequestWithUser extends Request {
  user: { uid: string; [k: string]: unknown };
}

/**
 * Calls API
 * Provides Agora RTC tokens and call offer (create, accept, decline, cancel).
 * All endpoints require Firebase ID token in Authorization: Bearer <token>.
 */
@Controller('calls')
@UseGuards(FirebaseAuthGuard)
export class CallsController {
  constructor(
    private readonly agoraTokenService: AgoraTokenService,
    private readonly callOfferService: CallOfferService,
  ) {}

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
   * Check if Agora is configured (does not require token generation).
   * GET /calls/agora-status
   */
  @Get('agora-status')
  getAgoraStatus(): { configured: boolean; message?: string } {
    return this.agoraTokenService.isConfigured();
  }

  /**
   * Get Agora App ID only (e.g. for client config before joining).
   * GET /calls/config
   */
  @Get('config')
  getConfig(): { appId: string } {
    return { appId: this.agoraTokenService.getAppId() };
  }

  /**
   * Create a call offer (caller starts call to callee).
   * POST /calls/offer
   * Body: { calleeUserId: string }
   */
  @Post('offer')
  async createOffer(
    @Req() req: RequestWithUser,
    @Body() dto: CreateOfferDto,
  ): Promise<CreateOfferResponseDto> {
    const callerUid = req.user?.uid ?? '';
    return this.callOfferService.createOffer(callerUid, dto.calleeUserId);
  }

  /**
   * Callee accepts the call. Returns Agora token and channel info.
   * POST /calls/offer/:callId/accept
   */
  @Post('offer/:callId/accept')
  async acceptOffer(
    @Req() req: RequestWithUser,
    @Param('callId', ParseUUIDPipe) callId: string,
  ): Promise<AcceptOfferResponseDto> {
    const calleeUid = req.user?.uid ?? '';
    return this.callOfferService.acceptOffer(callId, calleeUid);
  }

  /**
   * Callee declines the call.
   * POST /calls/offer/:callId/decline
   */
  @Post('offer/:callId/decline')
  async declineOffer(
    @Req() req: RequestWithUser,
    @Param('callId', ParseUUIDPipe) callId: string,
  ): Promise<{ status: string }> {
    const calleeUid = req.user?.uid ?? '';
    await this.callOfferService.declineOffer(callId, calleeUid);
    return { status: 'declined' };
  }

  /**
   * Caller cancels the call.
   * POST /calls/offer/:callId/cancel
   */
  @Post('offer/:callId/cancel')
  async cancelOffer(
    @Req() req: RequestWithUser,
    @Param('callId', ParseUUIDPipe) callId: string,
  ): Promise<{ status: string }> {
    const callerUid = req.user?.uid ?? '';
    await this.callOfferService.cancelOffer(callId, callerUid);
    return { status: 'cancelled' };
  }

  /**
   * Get call offer by id (e.g. when app opened from notification).
   * GET /calls/offer/:callId
   */
  @Get('offer/:callId')
  async getOffer(
    @Param('callId', ParseUUIDPipe) callId: string,
  ): Promise<{ callId: string; channelName: string; status: string; callerName: string }> {
    const offer = this.callOfferService.getOffer(callId);
    if (!offer) throw new NotFoundException('Call offer not found or expired');
    return {
      callId: offer.callId,
      channelName: offer.channelName,
      status: offer.status,
      callerName: offer.callerName,
    };
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
