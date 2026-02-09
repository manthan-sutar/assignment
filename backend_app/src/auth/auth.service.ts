import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as path from 'path';
import * as fs from 'fs';
import { randomUUID } from 'crypto';
import { FirebaseService } from '../common/services/firebase.service';
import { User } from '../users/entities/user.entity';
import { SignInDto } from './dto/sign-in.dto';
import { SignUpDto } from './dto/sign-up.dto';
import { UpdateProfileInput } from './dto/update-profile.dto';
import {
  AuthResponseDto,
  UserNotFoundResponseDto,
} from './dto/auth-response.dto';

const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
];
const ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

function isAllowedImage(mimetype: string | undefined, originalname: string | undefined): boolean {
  const mime = (mimetype || '').toLowerCase().split(';')[0].trim();
  if (ALLOWED_IMAGE_MIMES.includes(mime)) return true;
  const ext = (originalname || '').split('.').pop()?.toLowerCase();
  return ext != null && ALLOWED_EXTENSIONS.includes(ext);
}
const MAX_PHOTO_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

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
   * Update FCM device token for the current user (for push notifications).
   */
  async updateFcmToken(firebaseUid: string, fcmToken: string | null): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { firebaseUid },
    });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    user.fcmToken = fcmToken?.trim() || null;
    await this.userRepository.save(user);
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

  /**
   * Update profile (displayName and optional photo).
   * Used for onboarding and profile settings.
   */
  async updateProfile(
    firebaseUid: string,
    input: UpdateProfileInput,
  ): Promise<User> {
    const displayName =
      typeof input.displayName === 'string' ? input.displayName.trim() : '';
    if (!displayName) {
      throw new BadRequestException('Name is required');
    }
    if (displayName.length > 100) {
      throw new BadRequestException('Name must be at most 100 characters');
    }

    const user = await this.userRepository.findOne({
      where: { firebaseUid },
    });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    let photoURL: string | null = null;
    if (input.photo?.buffer && input.photo.buffer.length > 0) {
      if (input.photo.size > MAX_PHOTO_SIZE_BYTES) {
        throw new BadRequestException(
          `Photo must be under ${MAX_PHOTO_SIZE_BYTES / 1024 / 1024} MB`,
        );
      }
      if (!isAllowedImage(input.photo.mimetype, input.photo.originalname)) {
        throw new BadRequestException(
          'Photo must be JPG, JPEG, PNG, GIF, or WebP',
        );
      }
      const mime = (input.photo.mimetype || '').toLowerCase().split(';')[0].trim();
      const extFromMime = mime.split('/')[1] || '';
      const extFromName = (input.photo.originalname || '').split('.').pop()?.toLowerCase();
      const ext = (extFromMime || extFromName || 'jpg').replace('jpeg', 'jpg');
      const filename = `${randomUUID()}.${ext}`;
      const uploadsDir = path.join(process.cwd(), 'public', 'uploads', 'avatars');
      try {
        if (!fs.existsSync(uploadsDir)) {
          fs.mkdirSync(uploadsDir, { recursive: true });
        }
        const filePath = path.join(uploadsDir, filename);
        fs.writeFileSync(filePath, input.photo.buffer);
        photoURL = `/uploads/avatars/${filename}`;
      } catch (err) {
        throw new BadRequestException(
          `Failed to save photo: ${err instanceof Error ? err.message : 'Unknown error'}`,
        );
      }
    }

    user.displayName = displayName;
    if (photoURL !== null) {
      user.photoURL = photoURL;
    }
    return this.userRepository.save(user);
  }

  /**
   * List users for "Find people" – all users except the current one.
   * Returns public fields only: id, displayName, photoURL.
   */
  async listUsersExcept(firebaseUid: string): Promise<Array<{ id: string; displayName: string | null; photoURL: string | null }>> {
    const users = await this.userRepository.find({
      where: {},
      select: ['id', 'displayName', 'photoURL', 'firebaseUid'],
    });
    const filtered = users.filter((u) => u.firebaseUid !== firebaseUid);
    return filtered.map((u) => ({
      id: u.id,
      displayName: u.displayName ?? null,
      photoURL: u.photoURL && u.photoURL.trim() !== '' ? u.photoURL : null,
    }));
  }
}
