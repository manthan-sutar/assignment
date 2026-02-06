import { IsString, IsNotEmpty, IsBoolean } from 'class-validator';

/**
 * Sign Up DTO
 * Request body for sign-up endpoint
 * Includes consent flag to confirm user agreement
 */
export class SignUpDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;

  @IsBoolean()
  consent: boolean;
}
