import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RtcTokenBuilder, RtcRole } from 'agora-token';
import { TokenResponseDto } from '../dto/token-response.dto';

/** Default token validity (seconds). */
const DEFAULT_TOKEN_EXPIRE_SEC = 3600;

/**
 * Generates Agora RTC tokens for voice/video calls and live audio streaming.
 * Requires AGORA_APP_ID and AGORA_APP_CERTIFICATE in env.
 */
@Injectable()
export class AgoraTokenService {
  constructor(private readonly configService: ConfigService) {}

  /**
   * Generate an RTC token for the given channel and uid.
   * Used for both 1:1 calling and live streaming (publisher = host, subscriber = audience).
   */
  generateRtcToken(
    channelName: string,
    uid: number,
    role: 'publisher' | 'subscriber' = 'publisher',
    expireSeconds: number = DEFAULT_TOKEN_EXPIRE_SEC,
  ): TokenResponseDto {
    const appId = this.configService.get<string>('AGORA_APP_ID');
    const appCertificate = this.configService.get<string>('AGORA_APP_CERTIFICATE');

    if (!appId?.trim()) {
      throw new Error('AGORA_APP_ID is not configured');
    }
    if (!appCertificate?.trim()) {
      throw new Error('AGORA_APP_CERTIFICATE is not configured');
    }

    const rtcRole = role === 'subscriber' ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      rtcRole,
      expireSeconds,
      expireSeconds,
    );

    return {
      token,
      channelName,
      uid,
      appId,
      expiresIn: expireSeconds,
    };
  }

  /** Get Agora App ID (for client-side engine creation). */
  getAppId(): string {
    const appId = this.configService.get<string>('AGORA_APP_ID');
    if (!appId?.trim()) {
      throw new Error('AGORA_APP_ID is not configured');
    }
    return appId;
  }
}
