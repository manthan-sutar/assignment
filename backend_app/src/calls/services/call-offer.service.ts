import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';
import { FirebaseService } from '../../common/services/firebase.service';
import { SignalingGateway } from '../../signaling/signaling/signaling.gateway';
import { AgoraTokenService } from './agora-token.service';
import {
  CallOfferStore,
  CallOffer,
  CallOfferStatus,
} from './call-offer.store';
import { CreateOfferResponseDto } from '../dto/offer-response.dto';
import { AcceptOfferResponseDto } from '../dto/offer-response.dto';

@Injectable()
export class CallOfferService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly agoraTokenService: AgoraTokenService,
    private readonly offerStore: CallOfferStore,
    private readonly firebaseService: FirebaseService,
    private readonly signalingGateway: SignalingGateway,
  ) {}

  /**
   * Create a call offer. Caller is identified by firebaseUid.
   */
  async createOffer(
    callerFirebaseUid: string,
    calleeUserId: string,
  ): Promise<CreateOfferResponseDto> {
    this.offerStore.pruneExpired();

    const caller = await this.userRepository.findOne({
      where: { firebaseUid: callerFirebaseUid },
    });
    if (!caller) {
      throw new BadRequestException('Caller user not found');
    }

    const callee = await this.userRepository.findOne({
      where: { id: calleeUserId },
    });
    if (!callee) {
      throw new BadRequestException('Callee user not found');
    }
    if (callee.firebaseUid === callerFirebaseUid) {
      throw new BadRequestException('Cannot call yourself');
    }

    const callId = randomUUID();
    const channelName = `call_${callId}`;

    const offer: CallOffer = {
      callId,
      channelName,
      callerId: callerFirebaseUid,
      calleeId: callee.firebaseUid,
      callerName: caller.displayName || 'Unknown',
      calleeName: callee.displayName || 'Unknown',
      status: 'ringing',
      createdAt: new Date(),
    };
    this.offerStore.set(offer);

    if (!callee.fcmToken) {
      console.warn(
        `[CallOfferService] Callee ${callee.id} (firebaseUid=${offer.calleeId}) has no FCM token; incoming call will not be delivered via push.`,
      );
    }
    if (callee.fcmToken) {
      try {
        // Data-only (no notification payload) so the app's FCM background handler
        // is invoked when app is in background/killed; then we show CallKit/full-screen.
        console.log(
          `[CallOfferService] Sending incoming_call FCM to callee ${callee.id} token=${callee.fcmToken?.slice?.(0, 10) ?? 'null'}... callId=${callId}`,
        );
        await this.firebaseService.sendToToken(callee.fcmToken, {
          type: 'incoming_call',
          callId,
          channelName,
          callerId: callerFirebaseUid,
          callerName: offer.callerName,
        });
        console.log(
          `[CallOfferService] FCM incoming_call sent successfully for callId=${callId}`,
        );
      } catch (err: unknown) {
        const code =
          (err as { code?: string })?.code ??
          (err as { errorInfo?: { code?: string } })?.errorInfo?.code;
        if (code?.includes('registration-token-not-registered')) {
          callee.fcmToken = null;
          await this.userRepository.save(callee);
          console.warn(
            `[CallOfferService] Cleared stale FCM token for callee ${callee.id}; next token upload will fix push.`,
          );
        }
      }
    }
    console.log(
      `[CallOfferService] Emitting incoming_call over WebSocket to firebaseUid=${offer.calleeId} callId=${callId}`,
    );
    this.signalingGateway.emitToUser(offer.calleeId, 'incoming_call', {
      callId,
      channelName,
      callerId: callerFirebaseUid,
      callerName: offer.callerName,
    });

    return {
      callId,
      channelName,
      status: 'ringing',
    };
  }

  /**
   * Callee accepts. Returns Agora token and channel info.
   */
  async acceptOffer(
    callId: string,
    calleeFirebaseUid: string,
  ): Promise<AcceptOfferResponseDto> {
    const offer = this.offerStore.get(callId);
    if (!offer) {
      throw new NotFoundException('Call offer not found or expired');
    }
    if (offer.status !== 'ringing') {
      throw new BadRequestException(`Call already ${offer.status}`);
    }
    if (offer.calleeId !== calleeFirebaseUid) {
      throw new ForbiddenException('Not the callee of this call');
    }

    this.offerStore.updateStatus(callId, 'accepted');

    const caller = await this.userRepository.findOne({
      where: { firebaseUid: offer.callerId },
    });
    if (caller?.fcmToken) {
      try {
        await this.firebaseService.sendToToken(
          caller.fcmToken,
          {
            type: 'call_accepted',
            callId,
            channelName: offer.channelName,
          },
          { title: 'Call accepted', body: `${offer.calleeName} accepted your call` },
        );
      } catch (err: unknown) {
        const code =
          (err as { code?: string })?.code ??
          (err as { errorInfo?: { code?: string } })?.errorInfo?.code;
        if (code?.includes('registration-token-not-registered') && caller) {
          caller.fcmToken = null;
          await this.userRepository.save(caller);
        }
      }
    }
    this.signalingGateway.emitToUser(offer.callerId, 'call_accepted', {
      callId,
      channelName: offer.channelName,
    });

    const uid = this.uidFromFirebaseUid(calleeFirebaseUid);
    const tokenResult = this.agoraTokenService.generateRtcToken(
      offer.channelName,
      uid,
      'publisher',
    );

    return {
      token: tokenResult.token,
      channelName: offer.channelName,
      appId: tokenResult.appId,
      uid: tokenResult.uid,
      expiresIn: tokenResult.expiresIn,
    };
  }

  /**
   * Callee declines.
   */
  async declineOffer(callId: string, calleeFirebaseUid: string): Promise<void> {
    const offer = this.offerStore.get(callId);
    if (!offer) {
      throw new NotFoundException('Call offer not found or expired');
    }
    if (offer.status !== 'ringing') {
      return;
    }
    if (offer.calleeId !== calleeFirebaseUid) {
      throw new ForbiddenException('Not the callee of this call');
    }
    this.offerStore.updateStatus(callId, 'declined');

    const caller = await this.userRepository.findOne({
      where: { firebaseUid: offer.callerId },
    });
    if (caller?.fcmToken) {
      try {
        await this.firebaseService.sendToToken(
          caller.fcmToken,
          { type: 'call_declined', callId },
          { title: 'Call declined', body: `${offer.calleeName} declined your call` },
        );
      } catch (err: unknown) {
        const code =
          (err as { code?: string })?.code ??
          (err as { errorInfo?: { code?: string } })?.errorInfo?.code;
        if (code?.includes('registration-token-not-registered') && caller) {
          caller.fcmToken = null;
          await this.userRepository.save(caller);
        }
      }
    }
    this.signalingGateway.emitToUser(offer.callerId, 'call_declined', { callId });
  }

  /**
   * Caller cancels.
   */
  async cancelOffer(callId: string, callerFirebaseUid: string): Promise<void> {
    const offer = this.offerStore.get(callId);
    if (!offer) {
      throw new NotFoundException('Call offer not found or expired');
    }
    if (offer.status !== 'ringing') {
      return;
    }
    if (offer.callerId !== callerFirebaseUid) {
      throw new ForbiddenException('Not the caller of this call');
    }
    this.offerStore.updateStatus(callId, 'cancelled');

    const callee = await this.userRepository.findOne({
      where: { firebaseUid: offer.calleeId },
    });
    if (callee?.fcmToken) {
      try {
        await this.firebaseService.sendToToken(
          callee.fcmToken,
          { type: 'call_cancelled', callId },
          { title: 'Call cancelled', body: `${offer.callerName} cancelled the call` },
        );
      } catch (err: unknown) {
        const code =
          (err as { code?: string })?.code ??
          (err as { errorInfo?: { code?: string } })?.errorInfo?.code;
        if (code?.includes('registration-token-not-registered') && callee) {
          callee.fcmToken = null;
          await this.userRepository.save(callee);
        }
      }
    }
    this.signalingGateway.emitToUser(offer.calleeId, 'call_cancelled', { callId });
  }

  /**
   * Get offer by id (e.g. for app opened from notification).
   */
  getOffer(callId: string): CallOffer | undefined {
    return this.offerStore.get(callId);
  }

  /** For FCM/WebSocket: get offer and callee/caller info. */
  getOfferForNotification(callId: string): CallOffer | undefined {
    return this.offerStore.get(callId);
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
