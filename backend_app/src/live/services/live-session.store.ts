import { Injectable } from '@nestjs/common';

export interface LiveSession {
  sessionId: string;
  channelName: string;
  hostUserId: string;
  hostDisplayName: string;
  startedAt: Date;
}

/**
 * In-memory store of active live streams. Real-time: when host ends, session is removed.
 */
@Injectable()
export class LiveSessionStore {
  private readonly sessions = new Map<string, LiveSession>();

  set(session: LiveSession): void {
    this.sessions.set(session.sessionId, session);
  }

  get(sessionId: string): LiveSession | undefined {
    return this.sessions.get(sessionId);
  }

  getByHostUserId(hostUserId: string): LiveSession | undefined {
    for (const s of this.sessions.values()) {
      if (s.hostUserId === hostUserId) return s;
    }
    return undefined;
  }

  remove(sessionId: string): boolean {
    return this.sessions.delete(sessionId);
  }

  getAll(): LiveSession[] {
    return Array.from(this.sessions.values());
  }
}
