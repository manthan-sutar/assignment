import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';

/**
 * Guard for admin-only endpoints.
 * Expects header X-Admin-Key to match ADMIN_API_KEY env var.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const key = request.headers['x-admin-key'];
    const expected = this.configService.get<string>('ADMIN_API_KEY');
    if (!expected) {
      throw new UnauthorizedException('Admin API not configured');
    }
    if (key !== expected) {
      throw new UnauthorizedException('Invalid admin key');
    }
    return true;
  }
}
