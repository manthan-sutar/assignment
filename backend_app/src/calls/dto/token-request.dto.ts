import {
  IsString,
  IsOptional,
  IsInt,
  Min,
  Max,
  IsIn,
} from 'class-validator';

/**
 * Request body for generating an Agora RTC token.
 * Used for both calling and live audio streaming.
 */
export class TokenRequestDto {
  /** Agora channel name. Both caller and callee must use the same channel. */
  @IsString()
  channelName!: string;

  /** Optional. Agora uid (1 to 2^32-1). If omitted, server generates one from user id hash. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(2 ** 32 - 1)
  uid?: number;

  /** Optional. 'publisher' (default) = can publish audio; 'subscriber' = listen only. */
  @IsOptional()
  @IsString()
  @IsIn(['publisher', 'subscriber'])
  role?: 'publisher' | 'subscriber';
}
