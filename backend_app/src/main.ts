import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { AppModule } from './app.module';

/**
 * Bootstrap function
 * Initializes NestJS application
 * Enables CORS and global validation
 */
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Use Socket.IO adapter so WebSocketGateway with socket.io works (signaling, calls).
  app.useWebSocketAdapter(new IoAdapter(app));

  // Enable CORS for frontend communication
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // Global validation pipe for DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`Application is running on: http://localhost:${port}`);
}
bootstrap();
