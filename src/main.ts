import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { DEFAULT_PORT, RADIX_DECIMAL } from './shared';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const port = parseInt(process.env['PORT'] ?? String(DEFAULT_PORT), RADIX_DECIMAL);
  await app.listen(port);
}

void bootstrap();
