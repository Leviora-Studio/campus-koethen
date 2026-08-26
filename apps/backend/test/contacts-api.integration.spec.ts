import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { ContactsService } from '../src/modules/contacts/contacts.service';

// Starting the real Nest application can exceed Jest's 5s default on shared CI.
jest.setTimeout(60_000);

/**
 * Route-level test for the contact endpoints.
 *
 * `search-index` and `:slug` live on the same path. Which one answers
 * `/v1/contact-areas/search-index` is decided by declaration order, and getting
 * that wrong fails in exactly one way: the index responds "contact area
 * 'search-index' not found". That is worth a real HTTP request to rule out.
 *
 * The service is stubbed — this is about routing, not about Strapi.
 */
describe('/v1/contact-areas (integration)', () => {
  let app: INestApplication;

  const searchIndex = jest.fn();
  const getArea = jest.fn();

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ContactsService)
      .useValue({
        listAreas: async () => ({ data: [], translationFallback: false }),
        searchIndex,
        getArea,
      })
      .compile();

    app = moduleRef.createNestApplication({ logger: false });
    app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  beforeEach(() => {
    searchIndex.mockReset();
    getArea.mockReset();
    searchIndex.mockResolvedValue({ data: [], translationFallback: false });
    getArea.mockResolvedValue({
      data: { slug: 'x', name: 'X' },
      translationFallback: false,
      droppedBlockTypes: [],
    });
  });

  it('serves the search index rather than treating it as a slug', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/contact-areas/search-index')
      .expect(200);

    expect(searchIndex).toHaveBeenCalledTimes(1);
    expect(getArea).not.toHaveBeenCalled();
    expect((response.body as { data: unknown[] }).data).toEqual([]);
  });

  it('still routes a real slug to the detail endpoint', async () => {
    await request(app.getHttpServer()).get('/v1/contact-areas/studierendenrat').expect(200);

    expect(getArea).toHaveBeenCalledTimes(1);
    expect(getArea.mock.calls[0]![1]).toBe('studierendenrat');
  });

  it('passes the requested locale through', async () => {
    await request(app.getHttpServer()).get('/v1/contact-areas/search-index?locale=en').expect(200);

    expect(searchIndex.mock.calls[0]![0]).toMatchObject({ resolvedLocale: 'en' });
  });

  it('rejects an unsupported locale instead of silently answering in German', async () => {
    await request(app.getHttpServer()).get('/v1/contact-areas/search-index?locale=fr').expect(400);

    expect(searchIndex).not.toHaveBeenCalled();
  });
});
