/**
 * One live stream session (for GET /live/sessions and WS events).
 */
export class LiveSessionDto {
  sessionId!: string;
  channelName!: string;
  hostUserId!: string;
  hostDisplayName!: string;
  startedAt!: string; // ISO date string
}
