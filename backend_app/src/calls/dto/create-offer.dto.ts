import { IsString, IsUUID } from 'class-validator';

/**
 * Body for POST /calls/offer — create a call offer to the given user.
 */
export class CreateOfferDto {
  /** Callee user id (UUID from users table). */
  @IsUUID()
  calleeUserId!: string;
}
