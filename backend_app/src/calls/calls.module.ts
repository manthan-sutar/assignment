import { Module } from '@nestjs/common';
import { CallsController } from './calls.controller';
import { AgoraTokenService } from './services/agora-token.service';

@Module({
  controllers: [CallsController],
  providers: [AgoraTokenService],
  exports: [AgoraTokenService],
})
export class CallsModule {}
