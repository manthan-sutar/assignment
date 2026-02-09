import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';
import { AgoraTokenService } from '../../calls/services/agora-token.service';
import { SignalingGateway } from '../../signaling/signaling/signaling.gateway';
import { FirebaseService } from '../../common/services/firebase.service';
import { LiveSessionStore } from './live-session.store';
import { StartLiveResponseDto } from '../dto/start-live-response.dto';
import { LiveSessionDto } from '../dto/live-session.dto';

/** FCM topic all app users subscribe to for "someone went live" notifications. */
export const LIVE_TOPIC = 'live_sessions';

@Injectable()
export class LiveService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly agoraTokenService: AgoraTokenService,
    private readonly sessionStore: LiveSessionStore,
    private readonly signalingGateway: SignalingGateway,
    private readonly firebaseService: FirebaseService,
  ) {}

  /**
   * Start a live stream. Returns token and channel info for the host (publisher).
   */
  async startLive(hostFirebaseUid: string): Promise<StartLiveResponseDto> {
    const existing = this.sessionStore.getByHostUserId(hostFirebaseUid);
    if (existing) {
      throw new BadRequestException('You are already live. End the current stream first.');
    }

    const user = await this.userRepository.findOne({
      where: { firebaseUid: hostFirebaseUid },
    });
    if (!user) {
      throw new BadRequestException('User not found');
    }

    const sessionId = randomUUID();
    const channelName = `live_${sessionId}`;
    const uid = this.uidFromFirebaseUid(hostFirebaseUid);
    const tokenResult = this.agoraTokenService.generateRtcToken(
      channelName,
      uid,
      'publisher',
    );

    const session = {
      sessionId,
      channelName,
      hostUserId: hostFirebaseUid,
      hostDisplayName: user.displayName || 'Unknown',
      startedAt: new Date(),
    };
    this.sessionStore.set(session);

    const dto: LiveSessionDto = {
      sessionId: session.sessionId,
      channelName: session.channelName,
      hostUserId: session.hostUserId,
      hostDisplayName: session.hostDisplayName,
      startedAt: session.startedAt.toISOString(),
    };
    this.signalingGateway.broadcastToAll('live_started', dto);

    this.firebaseService
      .sendToTopic(
        LIVE_TOPIC,
        {
          type: 'live_started',
          sessionId: dto.sessionId,
          channelName: dto.channelName,
          hostUserId: dto.hostUserId,
          hostDisplayName: dto.hostDisplayName,
          startedAt: dto.startedAt,
        },
        {
          title: 'Live now',
          body: `${dto.hostDisplayName} is live`,
        },
      )
      .catch((err) => console.error('LiveService sendToTopic:', err));

    return {
      sessionId,
      channelName,
      token: tokenResult.token,
      appId: tokenResult.appId,
      uid: tokenResult.uid,
      expiresIn: tokenResult.expiresIn,
    };
  }

  /**
   * End the live stream for the given host. Removes session and notifies all clients.
   */
  async endLive(hostFirebaseUid: string): Promise<{ sessionId: string }> {
    const session = this.sessionStore.getByHostUserId(hostFirebaseUid);
    if (!session) {
      throw new BadRequestException('You are not live');
    }
    this.sessionStore.remove(session.sessionId);
    this.signalingGateway.broadcastToAll('live_ended', {
      sessionId: session.sessionId,
      channelName: session.channelName,
    });
    return { sessionId: session.sessionId };
  }

  /**
   * Get a new host token for the current user's active live session.
   * Use when the host navigated away but the stream is still running (e.g. re-enter host screen).
   */
  getHostToken(hostFirebaseUid: string): StartLiveResponseDto | null {
    const session = this.sessionStore.getByHostUserId(hostFirebaseUid);
    if (!session) return null;
    const uid = this.uidFromFirebaseUid(hostFirebaseUid);
    const tokenResult = this.agoraTokenService.generateRtcToken(
      session.channelName,
      uid,
      'publisher',
    );
    return {
      sessionId: session.sessionId,
      channelName: session.channelName,
      token: tokenResult.token,
      appId: tokenResult.appId,
      uid: tokenResult.uid,
      expiresIn: tokenResult.expiresIn,
    };
  }

  /**
   * List all active live sessions (for dashboard / discovery).
   */
  getSessions(): LiveSessionDto[] {
    return this.sessionStore.getAll().map((s) => ({
      sessionId: s.sessionId,
      channelName: s.channelName,
      hostUserId: s.hostUserId,
      hostDisplayName: s.hostDisplayName,
      startedAt: s.startedAt.toISOString(),
    }));
  }

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
