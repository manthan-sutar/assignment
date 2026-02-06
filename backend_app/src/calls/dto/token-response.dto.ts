/**
 * Response for Agora RTC token request.
 * Client uses these to join the same channel for calling or streaming.
 */
export class TokenResponseDto {
  /** Agora RTC token. Pass to RtcEngine.joinChannel. */
  token!: string;

  /** Channel name (echo of request). */
  channelName!: string;

  /** Uid assigned for this session. Use when joining. */
  uid!: number;

  /** Agora App ID. Required by Flutter SDK to create the engine. */
  appId!: string;

  /** Token expiry in seconds from now. */
  expiresIn!: number;
}
