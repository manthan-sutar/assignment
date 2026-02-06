import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { FirebaseService } from './services/firebase.service';

/**
 * Firebase Module
 * Global module that provides Firebase Admin SDK service
 * Imported once in AppModule, available throughout the application
 */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [FirebaseService],
  exports: [FirebaseService],
})
export class FirebaseModule {}
