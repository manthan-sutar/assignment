import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FirebaseService } from '../common/services/firebase.service';
import { User } from '../users/entities/user.entity';
import { SignInDto } from './dto/sign-in.dto';
import { SignUpDto } from './dto/sign-up.dto';
import {
  AuthResponseDto,
  UserNotFoundResponseDto,
} from './dto/auth-response.dto';

/**
 * Auth Service
 * Handles authentication business logic
 * - Verifies Firebase tokens
 * - Checks if user exists in database
 * - Creates new users
 * - Returns appropriate responses for frontend
 */
@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private firebaseService: FirebaseService,
  ) {}

  /**
   * Sign In
   * Verifies Firebase token and checks if user exists
   * Returns user if exists, or user info with exists: false for sign-up flow
   */
  async signIn(signInDto: SignInDto): Promise<AuthResponseDto | UserNotFoundResponseDto> {
    try {
      // Verify Firebase ID token
      const decodedToken = await this.firebaseService.verifyIdToken(
        signInDto.idToken,
      );

      // Check if user exists in our database
      const user = await this.userRepository.findOne({
        where: { firebaseUid: decodedToken.uid },
      });

      if (user) {
        // User exists - return user data
        return {
          user,
          exists: true,
          message: 'Sign in successful',
        };
      } else {
        // User doesn't exist - return user info for sign-up flow
        // Get phone number from Firebase user
        const firebaseUser = await this.firebaseService.getUserByUid(decodedToken.uid);
        return {
          exists: false,
          userInfo: {
            email: decodedToken.email || '',
            phoneNumber: firebaseUser.phoneNumber || '',
            displayName: decodedToken.name || '',
            photoURL: decodedToken.picture || '',
            firebaseUid: decodedToken.uid,
          },
          message: 'User not found. Please sign up to create an account.',
        };
      }
    } catch (error) {
      throw new UnauthorizedException(`Authentication failed: ${error.message}`);
    }
  }

  /**
   * Sign Up
   * Creates a new user in database after verifying Firebase token
   * Requires consent flag to be true
   */
  async signUp(signUpDto: SignUpDto): Promise<AuthResponseDto> {
    // Check consent
    if (!signUpDto.consent) {
      throw new BadRequestException('User consent is required to create an account');
    }

    try {
      // Verify Firebase ID token
      const decodedToken = await this.firebaseService.verifyIdToken(
        signUpDto.idToken,
      );

      // Check if user already exists
      const existingUser = await this.userRepository.findOne({
        where: { firebaseUid: decodedToken.uid },
      });

      if (existingUser) {
        throw new BadRequestException('User already exists. Please sign in instead.');
      }

      // Get phone number from Firebase user
      const firebaseUser = await this.firebaseService.getUserByUid(decodedToken.uid);
      
      // Create new user
      const newUser = this.userRepository.create({
        email: decodedToken.email || '',
        phoneNumber: firebaseUser.phoneNumber || '',
        displayName: decodedToken.name || '',
        photoURL: decodedToken.picture || '',
        firebaseUid: decodedToken.uid,
      });

      const savedUser = await this.userRepository.save(newUser);

      return {
        user: savedUser,
        exists: true,
        message: 'Account created successfully',
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException(`Sign up failed: ${error.message}`);
    }
  }

  /**
   * Get current user by Firebase UID
   * Used for protected routes
   */
  async getCurrentUser(firebaseUid: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { firebaseUid },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return user;
  }

  /**
   * Verify token and return user info
   * Utility method for token verification
   */
  async verifyToken(idToken: string): Promise<{ uid: string; email: string }> {
    const decodedToken = await this.firebaseService.verifyIdToken(idToken);
    return {
      uid: decodedToken.uid,
      email: decodedToken.email || '',
    };
  }
}
