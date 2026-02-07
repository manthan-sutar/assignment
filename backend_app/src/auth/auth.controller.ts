import {
  Controller,
  Post,
  Body,
  Get,
  Patch,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AuthService } from './auth.service';
import { SignInDto } from './dto/sign-in.dto';
import { SignUpDto } from './dto/sign-up.dto';
import { FirebaseAuthGuard } from './guards/firebase-auth.guard';

const MAX_PHOTO_SIZE = 5 * 1024 * 1024; // 5 MB

/**
 * Auth Controller
 * Handles authentication HTTP endpoints
 * - POST /auth/sign-in - Sign in with Firebase token
 * - POST /auth/sign-up - Create new account with consent
 * - GET /auth/me - Get current authenticated user
 * - POST /auth/verify-token - Verify Firebase token
 */
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /**
   * Sign In Endpoint
   * POST /auth/sign-in
   * Verifies Firebase token and checks if user exists
   * Returns user if exists, or user info with exists: false for sign-up prompt
   */
  @Post('sign-in')
  @HttpCode(HttpStatus.OK)
  async signIn(@Body() signInDto: SignInDto) {
    return this.authService.signIn(signInDto);
  }

  /**
   * Sign Up Endpoint
   * POST /auth/sign-up
   * Creates new user account with consent
   * Requires consent: true in request body
   */
  @Post('sign-up')
  async signUp(@Body() signUpDto: SignUpDto) {
    return this.authService.signUp(signUpDto);
  }

  /**
   * Get Current User
   * GET /auth/me
   * Protected route - requires valid Firebase token
   * Returns current authenticated user information
   */
  @UseGuards(FirebaseAuthGuard)
  @Get('me')
  async getCurrentUser(@Request() req) {
    return this.authService.getCurrentUser(req.user.uid);
  }

  /**
   * List users (Find people)
   * GET /auth/users
   * Returns all users except the current one (id, displayName, photoURL).
   */
  @UseGuards(FirebaseAuthGuard)
  @Get('users')
  async listUsers(@Request() req: { user: { uid: string } }) {
    return this.authService.listUsersExcept(req.user.uid);
  }

  /**
   * Verify Token
   * POST /auth/verify-token
   * Utility endpoint to verify Firebase token
   * Returns token information if valid
   */
  @Post('verify-token')
  async verifyToken(@Body() body: { idToken: string }) {
    return this.authService.verifyToken(body.idToken);
  }

  /**
   * Update FCM token for push notifications (incoming call, etc.).
   * POST /auth/fcm-token
   * Body: { fcmToken: string } or { fcmToken: null } to clear.
   */
  @UseGuards(FirebaseAuthGuard)
  @Post('fcm-token')
  @HttpCode(HttpStatus.OK)
  async updateFcmToken(
    @Request() req: { user: { uid: string } },
    @Body() body: { fcmToken?: string | null },
  ) {
    const token =
      body.fcmToken !== undefined && body.fcmToken !== null
        ? String(body.fcmToken).trim()
        : null;
    await this.authService.updateFcmToken(req.user.uid, token || null);
    return { ok: true };
  }

  /**
   * Update profile (onboarding / settings)
   * PATCH /auth/profile
   * Body (multipart/form-data): displayName (required), photo (optional file)
   * Returns updated user. Requires valid Firebase token.
   */
  @UseGuards(FirebaseAuthGuard)
  @Patch('profile')
  @UseInterceptors(
    FileInterceptor('photo', {
      storage: memoryStorage(),
      limits: { fileSize: MAX_PHOTO_SIZE },
    }),
  )
  async updateProfile(
    @Request() req: { user: { uid: string } },
    @Body('displayName') displayName: unknown,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    const name =
      typeof displayName === 'string' ? displayName.trim() : String(displayName ?? '').trim();
    if (!name) {
      throw new BadRequestException('Name is required');
    }
    return this.authService.updateProfile(req.user.uid, {
      displayName: name,
      photo,
    });
  }
}


