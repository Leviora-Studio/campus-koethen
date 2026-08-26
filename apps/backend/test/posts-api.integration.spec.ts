// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { PostsService } from '../src/modules/posts/posts.service';

jest.setTimeout(60_000);

describe('/v1/posts (integration)', () => {
  let app: INestApplication;

  const getChannels = jest.fn();
  const getTags = jest.fn();
  const getPosts = jest.fn();
  const getEvents = jest.fn();
  const getPostBySlug = jest.fn();

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PostsService)
      .useValue({
        getChannels,
        getTags,
        getPosts,
        getEvents,
        getPostBySlug,
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
    getChannels.mockReset();
    getTags.mockReset();
    getPosts.mockReset();
    getEvents.mockReset();
    getPostBySlug.mockReset();

    getChannels.mockResolvedValue({ data: [], translationFallback: false });
    getTags.mockResolvedValue({ data: [], translationFallback: false });
    getPosts.mockResolvedValue({
      data: [],
      pagination: { page: 1, pageSize: 20, total: 0, totalPages: 0 },
      translationFallback: false,
      droppedBlockTypes: [],
    });
    getEvents.mockResolvedValue({
      data: [],
      pagination: { page: 1, pageSize: 20, total: 0, totalPages: 0 },
      translationFallback: false,
      droppedBlockTypes: [],
    });
    getPostBySlug.mockResolvedValue({
      data: {
        slug: 'test-post',
        title: 'Test Post',
        teaser: 'Teaser',
        tag: { slug: 'news', name: 'News' },
        primaryChannel: { slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
        channels: [{ slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' }],
        content: [],
        eventStart: null,
        eventEnd: null,
        eventAllDay: false,
      },
      translationFallback: false,
      droppedBlockTypes: [],
    });
  });

  it('GET /v1/posts/channels routes correctly', async () => {
    const res = await request(app.getHttpServer()).get('/v1/posts/channels').expect(200);
    expect(getChannels).toHaveBeenCalledTimes(1);
    expect((res.body as { data: unknown[] }).data).toEqual([]);
  });

  it('GET /v1/posts/tags routes correctly', async () => {
    const res = await request(app.getHttpServer()).get('/v1/posts/tags').expect(200);
    expect(getTags).toHaveBeenCalledTimes(1);
    expect((res.body as { data: unknown[] }).data).toEqual([]);
  });

  it('GET /v1/posts/events routes correctly and does not collide with :slug', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/posts/events?from=2026-09-01&to=2026-09-30')
      .expect(200);
    expect(getEvents).toHaveBeenCalledTimes(1);
    expect(getPostBySlug).not.toHaveBeenCalled();
    expect((res.body as { data: unknown[] }).data).toEqual([]);
  });

  it('GET /v1/posts routes list endpoint', async () => {
    const res = await request(app.getHttpServer()).get('/v1/posts?page=1&pageSize=20').expect(200);
    expect(getPosts).toHaveBeenCalledTimes(1);
    expect((res.body as { data: unknown[] }).data).toEqual([]);
  });

  it('GET /v1/posts/:slug routes detail endpoint', async () => {
    const res = await request(app.getHttpServer()).get('/v1/posts/test-post').expect(200);
    expect(getPostBySlug).toHaveBeenCalledTimes(1);
    expect(getPostBySlug.mock.calls[0]![1]).toBe('test-post');
    expect((res.body as { data: { slug: string } }).data.slug).toBe('test-post');
  });

  it('GET /v1/news returns 404 (breaking migration from news to posts)', async () => {
    await request(app.getHttpServer()).get('/v1/news').expect(404);
  });
});
