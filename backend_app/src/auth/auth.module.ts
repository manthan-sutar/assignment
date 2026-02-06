import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { User } from '../users/entities/user.entity';
import { FirebaseModule } from '../common/firebase.module';

/**
 * Auth Module
 * Handles authentication functionality
 * - Sign in with Firebase
 * - Sign up with consent
 * - Token verification
 * - Protected routes
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    FirebaseModule,
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService],
})
export class AuthModule {}
