import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { CallsModule } from './calls/calls.module';
import { AuthModule } from './auth/auth.module';
import { SignalingModule } from './signaling/signaling.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [CallsModule, AuthModule, SignalingModule, UsersModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
