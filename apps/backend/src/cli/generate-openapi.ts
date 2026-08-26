import { VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { AppModule } from '../app.module';
import { buildOpenApiConfig } from '../openapi';

/**
 * Writes packages/openapi/openapi.json from the live NestJS metadata.
 *
 * CI regenerates this and fails if the committed artifact differs, so the
 * published contract can never silently drift from the implementation.
 */
async function main(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });
  await app.init();

  const document = SwaggerModule.createDocument(app, buildOpenApiConfig(new DocumentBuilder()));

  const target = join(__dirname, '../../../../packages/openapi/openapi.json');
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, `${JSON.stringify(document, null, 2)}\n`, 'utf8');

  process.stdout.write(`Wrote ${target}\n`);

  await app.close();
  process.exit(0);
}

void main();
