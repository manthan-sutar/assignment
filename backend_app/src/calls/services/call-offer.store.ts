import { Injectable } from '@nestjs/common';

/**
 * In-memory call offer. Ephemeral; cleared on restart.
 */
export type CallOfferStatus =
  | 'ringing'
  | 'accepted'
  | 'declined'
  | 'cancelled';

export interface CallOffer {
  callId: string;
  channelName: string;
  callerId: string; // Firebase UID
  calleeId: string; // Firebase UID
  callerName: string;
  calleeName: string;
  status: CallOfferStatus;
  createdAt: Date;
}

const RINGING_TTL_MS = 60 * 1000; // 60 seconds

/**
 * In-memory store for active call offers. Not persisted.
 */
@Injectable()
export class CallOfferStore {
  private readonly offers = new Map<string, CallOffer>();

  set(offer: CallOffer): void {
    this.offers.set(offer.callId, offer);
  }

  get(callId: string): CallOffer | undefined {
    return this.offers.get(callId);
  }

  updateStatus(callId: string, status: CallOfferStatus): void {
    const offer = this.offers.get(callId);
    if (offer) offer.status = status;
  }

  remove(callId: string): void {
    this.offers.delete(callId);
  }

  /** Remove expired ringing offers (older than RINGING_TTL_MS). */
  pruneExpired(): void {
    const now = Date.now();
    for (const [id, offer] of this.offers.entries()) {
      if (
        offer.status === 'ringing' &&
        now - offer.createdAt.getTime() > RINGING_TTL_MS
      ) {
        this.offers.delete(id);
      }
    }
  }
}
