import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DEFAULT_PORTS } from '@fit-odyssey/config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  const port = process.env.PORT || DEFAULT_PORTS.API;
  await app.listen(port);
  console.log(`[Fit Odyssey API] Server listening on port ${port}`);
}

void bootstrap();
