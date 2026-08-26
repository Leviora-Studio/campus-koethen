import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { setupOpenApiDocs } from '../src/openapi';

jest.setTimeout(60_000);

/**
 * Whether the running API serves its own documentation.
 *
 * `/docs` is real HTML on the same origin the media endpoint serves bytes
 * from, and it runs under a deliberately looser CSP than the API. The contract
 * itself is published and versioned in packages/openapi/openapi.json, so a live
 * deployment does not need the page — DOCS_ENABLED decides, and in production it
 * defaults to off.
 */
describe('OpenAPI docs exposure (integration)', () => {
  async function boot(docsEnabled: boolean): Promise<INestApplication> {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    const app = moduleRef.createNestApplication({ logger: false });
    app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });
    app.useGlobalFilters(new AllExceptionsFilter());
    setupOpenApiDocs(app, docsEnabled);
    await app.init();
    return app;
  }

  it('serves the page and the document when enabled', async () => {
    const app = await boot(true);
    try {
      await request(app.getHttpServer()).get('/docs').expect(200);
      const json = await request(app.getHttpServer()).get('/docs-json').expect(200);
      expect((json.body as { openapi?: string }).openapi).toBeDefined();
    } finally {
      await app.close();
    }
  });

  it('serves neither when disabled', async () => {
    const app = await boot(false);
    try {
      await request(app.getHttpServer()).get('/docs').expect(404);
      await request(app.getHttpServer()).get('/docs-json').expect(404);
      // The routes that exist for a reason are untouched by the switch.
      await request(app.getHttpServer()).get('/health/live').expect(200);
    } finally {
      await app.close();
    }
  });
});
