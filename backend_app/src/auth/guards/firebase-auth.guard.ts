import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { FirebaseService } from '../../common/services/firebase.service';

/**
 * Firebase Auth Guard
 * Protects routes by verifying Firebase ID token
 * Extracts token from Authorization header
 * Attaches decoded token to request object
 */
@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(private firebaseService: FirebaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid authorization header');
    }

    const idToken = authHeader.substring(7); // Remove 'Bearer ' prefix

    try {
      // Verify token and attach user info to request
      const decodedToken = await this.firebaseService.verifyIdToken(idToken);
      request.user = decodedToken;
      return true;
    } catch (error) {
      throw new UnauthorizedException(`Invalid token: ${error.message}`);
    }
  }
}
