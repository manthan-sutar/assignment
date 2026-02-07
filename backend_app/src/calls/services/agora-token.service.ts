import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RtcTokenBuilder, RtcRole } from 'agora-token';
import { TokenResponseDto } from '../dto/token-response.dto';

/** Default token validity (seconds). */
const DEFAULT_TOKEN_EXPIRE_SEC = 3600;

const AGORA_CONFIG_MSG =
  'Agora is not configured. Add AGORA_APP_ID and AGORA_APP_CERTIFICATE to backend .env (see ENV_SETUP.md).';

/**
 * Generates Agora RTC tokens for voice/video calls and live audio streaming.
 * Requires AGORA_APP_ID and AGORA_APP_CERTIFICATE in env.
 */
@Injectable()
export class AgoraTokenService {
  private readonly logger = new Logger(AgoraTokenService.name);

  constructor(private readonly configService: ConfigService) {}

  /** Normalize env value: trim and optionally replace literal \\n with real newline (for .env cert). */
  private normalizeCert(cert: string | undefined): string {
    if (!cert || !cert.trim()) return '';
    let s = cert.trim();
    // If certificate was pasted in .env with \n as two chars, convert to actual newline
    if (s.includes('\\n')) s = s.replace(/\\n/g, '\n');
    return s;
  }

  private getAppIdRaw(): string {
    const raw = this.configService.get<string>('AGORA_APP_ID');
    return raw?.trim() ?? '';
  }

  private getAppCertificateRaw(): string {
    return this.normalizeCert(this.configService.get<string>('AGORA_APP_CERTIFICATE'));
  }

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
    const appId = this.getAppIdRaw();
    const appCertificate = this.getAppCertificateRaw();

    this.logger.log(
      `generateRtcToken channel=${channelName} uid=${uid} role=${role} appIdLen=${appId.length} certLen=${appCertificate.length}`,
    );

    if (!appId) {
      this.logger.warn('AGORA_APP_ID missing or empty');
      throw new ServiceUnavailableException(AGORA_CONFIG_MSG);
    }
    if (!appCertificate) {
      this.logger.warn('AGORA_APP_CERTIFICATE missing or empty');
      throw new ServiceUnavailableException(AGORA_CONFIG_MSG);
    }

    try {
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
      this.logger.log(`Token generated for channel=${channelName}`);
      return {
        token,
        channelName,
        uid,
        appId,
        expiresIn: expireSeconds,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Agora token generation failed: ${msg}`);
      throw new ServiceUnavailableException(msg || 'Agora token generation failed');
    }
  }

  /** Get Agora App ID (for client-side engine creation). */
  getAppId(): string {
    const appId = this.getAppIdRaw();
    if (!appId) {
      throw new ServiceUnavailableException(AGORA_CONFIG_MSG);
    }
    return appId;
  }

  /** Check if Agora is configured (for status/health). Does not throw. */
  isConfigured(): { configured: boolean; message?: string } {
    const appId = this.getAppIdRaw();
    const cert = this.getAppCertificateRaw();
    if (!appId) {
      return { configured: false, message: 'AGORA_APP_ID missing in .env' };
    }
    if (!cert) {
      return { configured: false, message: 'AGORA_APP_CERTIFICATE missing in .env' };
    }
    return { configured: true };
  }
}
