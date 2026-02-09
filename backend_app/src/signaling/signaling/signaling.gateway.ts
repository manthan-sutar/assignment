import {
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server } from 'socket.io';
import { Socket } from 'socket.io';
import { FirebaseService } from '../../common/services/firebase.service';

@WebSocketGateway({
  cors: { origin: '*' },
})
export class SignalingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  /** Map: socket.id -> Firebase UID */
  private readonly userIdBySocketId = new Map<string, string>();
  /** Map: Firebase UID -> Set of socket.id */
  private readonly socketIdsByUserId = new Map<string, Set<string>>();

  constructor(private readonly firebaseService: FirebaseService) {}

  handleConnection(_client: Socket) {
    // Registration happens on 'register' message
  }

  handleDisconnect(client: Socket) {
    const uid = this.userIdBySocketId.get(client.id);
    if (uid) {
      this.userIdBySocketId.delete(client.id);
      const set = this.socketIdsByUserId.get(uid);
      if (set) {
        set.delete(client.id);
        if (set.size === 0) this.socketIdsByUserId.delete(uid);
      }
    }
  }

  @SubscribeMessage('register')
  async handleRegister(
    client: Socket,
    payload: { idToken?: string },
  ): Promise<{ event: string; data: { ok: boolean; error?: string } }> {
    const idToken =
      payload && typeof payload.idToken === 'string' ? payload.idToken : null;
    if (!idToken) {
      return { event: 'registered', data: { ok: false, error: 'idToken required' } };
    }
    try {
      const decoded = await this.firebaseService.verifyIdToken(idToken);
      const uid = decoded.uid;

      this.userIdBySocketId.set(client.id, uid);
      if (!this.socketIdsByUserId.has(uid)) {
        this.socketIdsByUserId.set(uid, new Set());
      }
      this.socketIdsByUserId.get(uid)!.add(client.id);

      return { event: 'registered', data: { ok: true } };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Invalid token';
      return { event: 'registered', data: { ok: false, error: message } };
    }
  }

  /**
   * Emit an event to all sockets associated with a user (Firebase UID).
   * Used by CallOfferService to send incoming_call, call_accepted, etc.
   */
  emitToUser(userId: string, event: string, data: Record<string, unknown>): void {
    const socketIds = this.socketIdsByUserId.get(userId);
    if (socketIds && socketIds.size > 0) {
      for (const id of socketIds) {
        this.server.to(id).emit(event, data);
      }
    } else {
      console.warn(
        `[SignalingGateway] emitToUser: no socket for userId=${userId} (event=${event}). ` +
          'Callee may not be connected or not yet registered.',
      );
    }
  }

  /**
   * Broadcast an event to all connected clients (e.g. live_started, live_ended).
   */
  broadcastToAll(event: string, data: object): void {
    this.server.emit(event, data);
  }
}
