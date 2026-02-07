import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { CallsModule } from './calls/calls.module';
import { AuthModule } from './auth/auth.module';
import { SignalingModule } from './signaling/signaling.module';
import { UsersModule } from './users/users.module';
import { ReelsModule } from './reels/reels.module';
import { LiveModule } from './live/live.module';
import { FirebaseModule } from './common/firebase.module';
import { User } from './users/entities/user.entity';
import { Reel } from './reels/entities/reel.entity';

/**
 * App Module
 * Root module of the application
 * Configures global modules: Config, TypeORM, Firebase
 */
@Module({
  imports: [
    // Configuration module for environment variables
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    // TypeORM configuration for database connection
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => {
        const dbSync = configService.get<boolean>('DB_SYNC', false);
        return {
          type: 'postgres',
          host: configService.get<string>('DB_HOST', 'localhost'),
          port: configService.get<number>('DB_PORT', 5432),
          username: configService.get<string>('DB_USERNAME', 'postgres'),
          password: configService.get<string>('DB_PASSWORD', 'postgres'),
          database: configService.get<string>('DB_NAME', 'assignment_db'),
          entities: [User, Reel],
          synchronize: dbSync,
          // Don't fail if database is not available (for development)
          retryAttempts: 3,
          retryDelay: 3000,
        };
      },
      inject: [ConfigService],
    }),
    // Global Firebase module
    FirebaseModule,
    // Static files (e.g. admin UI)
    ServeStaticModule.forRoot({
      rootPath: join(__dirname, '..', 'public'),
      serveRoot: '/',
    }),
    // Feature modules
    CallsModule,
    AuthModule,
    SignalingModule,
    UsersModule,
    ReelsModule,
    LiveModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
