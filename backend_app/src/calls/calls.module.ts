import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../users/entities/user.entity';
import { SignalingModule } from '../signaling/signaling.module';
import { CallsController } from './calls.controller';
import { AgoraTokenService } from './services/agora-token.service';
import { CallOfferStore } from './services/call-offer.store';
import { CallOfferService } from './services/call-offer.service';

@Module({
  imports: [TypeOrmModule.forFeature([User]), SignalingModule],
  controllers: [CallsController],
  providers: [AgoraTokenService, CallOfferStore, CallOfferService],
  exports: [AgoraTokenService, CallOfferService],
})
export class CallsModule {}
