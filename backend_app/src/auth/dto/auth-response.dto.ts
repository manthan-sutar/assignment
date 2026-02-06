import { User } from '../../users/entities/user.entity';

/**
 * Auth Response DTO
 * Standard response format for authentication endpoints
 */
export class AuthResponseDto {
  user: User;
  token?: string;
  exists?: boolean;
  message?: string;
}

/**
 * User Not Found Response
 * Returned when user tries to sign in but doesn't exist
 * Frontend will show sign-up prompt with this response
 */
export class UserNotFoundResponseDto {
  exists: boolean;
  userInfo: {
    email: string;
    phoneNumber: string;
    displayName: string;
    photoURL: string;
    firebaseUid: string;
  };
  message: string;
}
