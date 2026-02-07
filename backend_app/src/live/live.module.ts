import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../users/entities/user.entity';
import { CallsModule } from '../calls/calls.module';
import { SignalingModule } from '../signaling/signaling.module';
import { LiveController } from './live.controller';
import { LiveService } from './services/live.service';
import { LiveSessionStore } from './services/live-session.store';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    CallsModule,
    SignalingModule,
  ],
  controllers: [LiveController],
  providers: [LiveSessionStore, LiveService],
  exports: [LiveService],
})
export class LiveModule {}
