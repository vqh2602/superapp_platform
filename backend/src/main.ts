import * as dotenv from 'dotenv';
dotenv.config({ override: true });
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { json } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('SuperAppRegistryBootstrap');
  const app = await NestFactory.create(AppModule, { bodyParser: false });

  app.use(json({ limit: '1mb' }));

  // Enable CORS for Flutter Master App and Web Builder
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const port = process.env.PORT || 3000;
  const host = process.env.IP || process.env.HOST || '::';
  await app.listen(port, host);
  logger.log(`Dynamic Mini App Registry & Catalog API running at http://${host}:${port}/api/v1/catalog/apps`);
}
bootstrap();
