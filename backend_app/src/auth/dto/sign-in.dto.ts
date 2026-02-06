import { IsString, IsNotEmpty } from 'class-validator';

/**
 * Sign In DTO
 * Request body for sign-in endpoint
 */
export class SignInDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;
}
