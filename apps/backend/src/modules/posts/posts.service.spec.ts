// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { StrapiClient } from '../strapi/strapi.client';
import { PostsService } from './posts.service';

interface Call {
  path: string;
  query: Record<string, unknown>;
}

function makeClient(handler: (call: Call) => unknown) {
  const calls: Call[] = [];
  const client = {
    get: jest.fn(async (path: string, query: Record<string, unknown>) => {
      const call = { path, query };
      calls.push(call);
      return handler(call);
    }),
  } as unknown as StrapiClient;
  return { client, calls };
}

const channel = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  name: slug,
  colorHex: '#5B3FD0',
  sortOrder: 0,
  isActive: true,
  defaultSubscribed: false,
  publicCalendar: null,
  ...over,
});

const tag = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  name: slug,
  isActive: true,
  ...over,
});

const post = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  title: `Title ${slug}`,
  publishedAt: '2026-07-01T00:00:00.000Z',
  tag: { slug: 'news', name: 'News' },
  primaryChannel: { slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
  channels: [{ slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' }],
  ...over,
});

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;
const en = { requestedLocale: 'en', resolvedLocale: 'en' } as const;

describe('PostsService', () => {
  describe('getChannels', () => {
    it('sorts by sortOrder then name and maps to the public shape including publicCalendarSlug', async () => {
      const { client } = makeClient(() => ({
        data: [
          channel('b', { sortOrder: 10, name: 'B', publicCalendar: { slug: 'cal-b' } }),
          channel('a', { sortOrder: 5, name: 'A' }),
          channel('c', { sortOrder: 10, name: 'A-first' }),
        ],
      }));
      const service = new PostsService(client);

      const result = await service.getChannels(de);

      expect(result.data.map((c) => c.slug)).toEqual(['a', 'c', 'b']);
      expect(result.data.find((c) => c.slug === 'b')?.publicCalendarSlug).toBe('cal-b');
      expect(result.data.find((c) => c.slug === 'a')?.publicCalendarSlug).toBeNull();
    });

    it('asks Strapi only for active channels with publicCalendar populated', async () => {
      const { client, calls } = makeClient(() => ({ data: [] }));
      await new PostsService(client).getChannels(de);

      expect(JSON.stringify(calls[0]!.query)).toContain('isActive');
      expect(JSON.stringify(calls[0]!.query)).toContain('publicCalendar');
    });

    it('marks a translation fallback when an English channel description is missing', async () => {
      const { client } = makeClient(({ query }) =>
        query['locale'] === 'en'
          ? { data: [] }
          : {
              data: [
                channel('campus-news', {
                  name: 'Campus News',
                  description: 'Deutsche Beschreibung',
                }),
              ],
            },
      );

      const result = await new PostsService(client).getChannels(en);

      expect(result.data[0]!.name).toBe('Campus News');
      expect(result.translationFallback).toBe(true);
    });
  });

  describe('getTags', () => {
    it('sorts by name then slug and maps to the minimal public shape', async () => {
      const { client } = makeClient(() => ({
        data: [tag('b', { name: 'B' }), tag('a', { name: 'A' }), tag('c', { name: 'A-first' })],
      }));

      const result = await new PostsService(client).getTags(de);

      expect(result.data.map((t) => t.slug)).toEqual(['a', 'c', 'b']);
    });

    it('starts the canonical and the translated fetch at the same time', async () => {
      // The two catalogues do not depend on each other. Awaiting the first
      // before starting the second doubled the latency of every English
      // request for nothing.
      let inFlight = 0;
      let concurrentPeak = 0;
      const client = {
        get: jest.fn(async () => {
          inFlight += 1;
          concurrentPeak = Math.max(concurrentPeak, inFlight);
          await Promise.resolve();
          inFlight -= 1;
          return { data: [tag('a', { name: 'A' })] };
        }),
      } as unknown as StrapiClient;

      await new PostsService(client).getTags(en);

      expect(concurrentPeak).toBe(2);
    });

    it('serves a repeat request from the cache instead of asking Strapi again', async () => {
      const { client, calls } = makeClient(() => ({ data: [tag('a')] }));
      const service = new PostsService(client);

      await service.getTags(de);
      await service.getTags(de);

      expect(calls).toHaveLength(1);
    });

    it('caches per locale, so German never answers an English request', async () => {
      const { client, calls } = makeClient((call) => ({
        data: [tag('a', { name: call.query['locale'] === 'en' ? 'English' : 'Deutsch' })],
      }));
      const service = new PostsService(client);

      expect((await service.getTags(de)).data[0]!.name).toBe('Deutsch');
      expect((await service.getTags(en)).data[0]!.name).toBe('English');
      // de: one call. en: canonical plus translated.
      expect(calls).toHaveLength(3);
    });

    it('does not cache a failure', async () => {
      let attempt = 0;
      const client = {
        get: jest.fn(async () => {
          attempt += 1;
          if (attempt === 1) throw new Error('upstream is down');
          return { data: [tag('a')] };
        }),
      } as unknown as StrapiClient;
      const service = new PostsService(client);

      await expect(service.getTags(de)).rejects.toThrow();
      await expect(service.getTags(de)).resolves.toMatchObject({
        data: [expect.objectContaining({ slug: 'a' })],
      });
    });
  });

  describe('getPosts', () => {
    it('returns empty list when channelsParamPresent is true but channels is empty', async () => {
      const { client, calls } = makeClient(() => ({ data: [] }));

      const result = await new PostsService(client).getPosts(de, {
        channels: [],
        channelsParamPresent: true,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data).toEqual([]);
      expect(calls).toHaveLength(0);
    });

    it('filters out posts missing a tag or primaryChannel defensively', async () => {
      const { client } = makeClient(() => ({
        data: [
          post('good'),
          {
            slug: 'no-tag',
            title: 'No Tag',
            primaryChannel: { slug: 'c1', name: 'C1', colorHex: '#fff' },
          },
          { slug: 'no-channel', title: 'No Channel', tag: { slug: 't1', name: 'T1' } },
        ],
      }));

      const result = await new PostsService(client).getPosts(de, {
        channels: [],
        channelsParamPresent: false,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data).toHaveLength(1);
      expect(result.data[0]?.slug).toBe('good');
    });

    it('sorts by publishedAt desc, then slug asc', async () => {
      const { client } = makeClient(() => ({
        data: [
          post('old', { publishedAt: '2026-01-01T00:00:00.000Z' }),
          post('same-b', { publishedAt: '2026-01-01T00:00:00.000Z' }),
          post('new', { publishedAt: '2026-06-01T00:00:00.000Z' }),
          post('same-a', { publishedAt: '2026-01-01T00:00:00.000Z' }),
        ],
      }));

      const result = await new PostsService(client).getPosts(de, {
        channels: [],
        channelsParamPresent: false,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data.map((p) => p.slug)).toEqual(['new', 'old', 'same-a', 'same-b']);
    });

    it('serves an identical repeat query from the list cache', async () => {
      const { client, calls } = makeClient(() => ({ data: [post('a')] }));
      const service = new PostsService(client);
      const query = {
        channels: [],
        channelsParamPresent: false,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      };

      const first = await service.getPosts(de, query);
      const second = await service.getPosts(de, query);

      expect(calls).toHaveLength(1);
      expect(second.data.map((p) => p.slug)).toEqual(first.data.map((p) => p.slug));
    });

    it('treats the same channel selection in a different order as one cache entry', async () => {
      const { client, calls } = makeClient(() => ({ data: [post('a')] }));
      const service = new PostsService(client);
      const base = {
        channelsParamPresent: true,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      };

      await service.getPosts(de, { ...base, channels: ['a', 'b'] });
      await service.getPosts(de, { ...base, channels: ['b', 'a'] });

      expect(calls).toHaveLength(1);
    });

    it('keeps a different page, locale or filter apart', async () => {
      const { client, calls } = makeClient(() => ({ data: [post('a')] }));
      const service = new PostsService(client);
      const base = {
        channels: [],
        channelsParamPresent: false,
        tags: [],
        tagsParamPresent: false,
        page: 1,
        pageSize: 20,
      };

      await service.getPosts(de, base);
      await service.getPosts(de, { ...base, page: 2 });
      await service.getPosts(de, { ...base, pageSize: 10 });
      await service.getPosts(de, { ...base, tags: ['event'], tagsParamPresent: true });
      const deCalls = calls.length;
      await service.getPosts(en, base);

      expect(deCalls).toBe(4);
      // English adds the canonical read plus the translated overlay.
      expect(calls.length).toBeGreaterThan(deCalls);
    });
  });

  describe('getEvents', () => {
    it('queries tag=event and date overlap interval', async () => {
      const { client, calls } = makeClient(() => ({
        data: [
          post('e1', {
            tag: { slug: 'event', name: 'Event' },
            eventStart: '2026-09-10T10:00:00.000Z',
          }),
        ],
      }));

      const result = await new PostsService(client).getEvents(de, {
        from: '2026-09-01',
        to: '2026-09-30',
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data).toHaveLength(1);
      const queryStr = JSON.stringify(calls[0]!.query);
      expect(queryStr).toContain('eventStart');
      expect(queryStr).toContain('2026-09-30T23:59:59.999Z');
      expect(queryStr).toContain('2026-09-01T00:00:00.000Z');
    });

    it('sorts events by eventStart asc, slug asc', async () => {
      const { client } = makeClient(() => ({
        data: [
          post('e2', {
            tag: { slug: 'event', name: 'Event' },
            eventStart: '2026-09-20T10:00:00.000Z',
          }),
          post('e1', {
            tag: { slug: 'event', name: 'Event' },
            eventStart: '2026-09-10T10:00:00.000Z',
          }),
          post('e3', {
            tag: { slug: 'event', name: 'Event' },
            eventStart: '2026-09-20T08:00:00.000Z',
          }),
        ],
      }));

      const result = await new PostsService(client).getEvents(de, {
        from: '2026-09-01',
        to: '2026-09-30',
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data.map((p) => p.slug)).toEqual(['e1', 'e3', 'e2']);
    });

    it('serves an identical repeat range from the events cache but not a different one', async () => {
      const { client, calls } = makeClient(() => ({
        data: [
          post('e1', {
            tag: { slug: 'event', name: 'Event' },
            eventStart: '2026-09-10T10:00:00.000Z',
          }),
        ],
      }));
      const service = new PostsService(client);
      const query = {
        from: '2026-09-01',
        to: '2026-09-30',
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      };

      await service.getEvents(de, query);
      await service.getEvents(de, query);
      expect(calls).toHaveLength(1);

      await service.getEvents(de, { ...query, from: '2026-10-01', to: '2026-10-31' });
      expect(calls).toHaveLength(2);
    });
  });

  describe('getPostBySlug', () => {
    it('returns detail post and raises 404 POST_NOT_FOUND when not found', async () => {
      const { client } = makeClient(({ query }) => {
        const filters = query['filters'] as Record<string, unknown> | undefined;
        const slugEq = (filters?.['slug'] as Record<string, unknown> | undefined)?.['$eq'];
        return {
          data: slugEq === 'found' ? [post('found')] : [],
        };
      });

      const service = new PostsService(client);
      const res = await service.getPostBySlug(de, 'found');
      expect(res.data.slug).toBe('found');

      await expect(service.getPostBySlug(de, 'unknown')).rejects.toMatchObject({
        code: 'POST_NOT_FOUND',
      });
    });

    it('serves repeat requests from the postDetailCache', async () => {
      const { client, calls } = makeClient(() => ({
        data: [post('cached-post')],
      }));

      const service = new PostsService(client);
      await service.getPostBySlug(de, 'cached-post');
      await service.getPostBySlug(de, 'cached-post');

      expect(calls).toHaveLength(1);
    });
  });
});
