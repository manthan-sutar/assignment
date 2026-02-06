import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Reel } from './entities/reel.entity';
import { ReelsService } from './reels.service';
import { ReelsController } from './reels.controller';

/**
 * Reels Module
 * Audio reels (audio + image) feed - consumption only.
 * Metadata in Postgres; media URLs point to Firebase Storage.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Reel])],
  controllers: [ReelsController],
  providers: [ReelsService],
  exports: [ReelsService],
})
export class ReelsModule {}
