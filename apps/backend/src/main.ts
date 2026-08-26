import { VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { Express } from 'express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { createResponseCompression } from './common/http/response-compression';
import { createSecurityHeaders } from './common/http/security-headers';
import { JsonLogger } from './common/logger/json-logger.service';
import { ENV } from './config/app-config.module';
import { Env } from './config/env.schema';
import { setupOpenApiDocs } from './openapi';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: new JsonLogger() });

  const env = app.get<Env>(ENV);

  // Content endpoints are versioned in the URI (/v1/...). Health and docs stay
  // unversioned so probes never break on a version bump.
  app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });

  // Express announces itself by default. The version it runs is nobody's
  // business and knowing it only helps someone pick an exploit.
  (app.getHttpAdapter().getInstance() as Express).disable('x-powered-by');

  // First in the chain, so the guards are on every response — including the
  // ones the exception filter produces and the bytes the media endpoint sends.
  app.use(createSecurityHeaders({ production: env.NODE_ENV === 'production' }));

  // Ahead of every route, so it also covers /docs and /docs-json. Purely a
  // transport encoding: a client that offers no `Accept-Encoding` gets exactly
  // the response it got before.
  app.use(createResponseCompression());

  app.enableCors({
    // A wildcard is rejected at config validation time when NODE_ENV=production.
    origin: env.CORS_ALLOWED_ORIGINS.includes('*') ? true : env.CORS_ALLOWED_ORIGINS,
    methods: ['GET', 'OPTIONS'],
    credentials: false,
    maxAge: 3600,
  });

  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableShutdownHooks();

  // Off in production unless DOCS_ENABLED says otherwise — see setupOpenApiDocs.
  setupOpenApiDocs(app, env.DOCS_ENABLED);

  await app.listen(env.PORT, env.HOST);
}

void bootstrap();
