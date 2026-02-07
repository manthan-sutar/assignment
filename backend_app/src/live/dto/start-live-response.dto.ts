/**
 * Response for POST /live/start. Host uses these to join Agora as publisher.
 */
export class StartLiveResponseDto {
  sessionId!: string;
  channelName!: string;
  token!: string;
  appId!: string;
  uid!: number;
  expiresIn!: number;
}
