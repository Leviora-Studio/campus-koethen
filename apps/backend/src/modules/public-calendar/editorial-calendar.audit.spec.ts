import { EditorialCalendarService } from './editorial-calendar.service';
import { PublicCalendarService } from './public-calendar.service';
import { StrapiClient } from '../strapi/strapi.client';
import { PostsService } from '../posts/posts.service';
import { Env } from '../../config/env.schema';

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;
const en = { requestedLocale: 'en', resolvedLocale: 'en' } as const;
const share = (id: string) =>
  `https://calendar.google.com/calendar/u/0?cid=${Buffer.from(id).toString('base64url')}`;
const calendar = {
  slug: 'demo',
  name: 'Demo calendar',
  isActive: true,
  googleShareUrl: share('demo@group.calendar.google.com'),
  includeEventDescription: false,
  includeEventLocation: false,
  channel: { slug: 'demo-channel', colorHex: '#123456' },
};
const entry = {
  slug: 'demo-entry',
  title: 'Demo entry',
  start: '2026-11-16T10:00:00Z',
  end: '2026-11-16T11:00:00Z',
  timeZone: 'Europe/Berlin',
  calendar: { slug: 'demo' },
};
const event = {
  id: 'demo-google',
  calendarId: 'internal-id',
  calendarSlug: 'demo',
  title: 'Demo Google event',
  description: 'Previously shared description',
  location: 'Previously shared location',
  start: entry.start,
  end: entry.end,
  allDay: false,
  status: 'confirmed',
};
function fixture(cal: Record<string, unknown> = calendar) {
  const get = jest.fn(async (path: string, _query: Record<string, unknown>) => ({
    data: path.includes('calendar-entries') ? [entry] : [cal],
    meta: { pagination: { pageCount: 1 } },
  }));
  const google = {
    listCalendars: jest.fn(async () => ({
      data: [
        {
          id: 'stored-id',
          slug: 'demo',
          googleOpenUrl: calendar.googleShareUrl,
          dataState: 'ready',
          dataStale: false,
          lastSuccessfulSyncAt: entry.start,
        },
      ],
      translationFallback: false,
    })),
    getAggregatedEvents: jest.fn(async (_slugs: string[]) => ({
      events: [event],
      truncated: false,
    })),
  };
  const posts = {
    getEvents: jest.fn(async () => ({
      data: [],
      pagination: { totalPages: 1 },
      translationFallback: false,
    })),
  };
  const service = new EditorialCalendarService(
    { get } as unknown as StrapiClient,
    google as unknown as PublicCalendarService,
    posts as unknown as PostsService,
    {
      PUBLIC_CALENDAR_API_MAX_EVENTS: 2,
      PUBLIC_CALENDAR_FALLBACK_TIME_ZONE: 'Europe/Berlin',
      PUBLIC_CALENDAR_API_MAX_CALENDARS: 50,
    } as Env,
  );
  return { service, get, google };
}
const from = new Date('2026-11-16'),
  to = new Date('2026-11-17');
describe('calendar review regressions', () => {
  it('redacts Google details immediately when the editorial sharing switches are off', async () => {
    const { service } = fixture();
    const result = await service.events(['demo'], from, to, de);
    expect(result.events.find((e) => e.source === 'google')).toMatchObject({
      description: null,
      location: null,
    });
  });
  it('does not serve events imported from a different Google calendar under the same slug', async () => {
    const { service, google } = fixture({
      ...calendar,
      googleShareUrl: share('other-demo@group.calendar.google.com'),
    });
    await service.events(['demo'], from, to, de);
    expect(google.getAggregatedEvents.mock.calls[0]?.[0]).toEqual([]);
  });
  it('keeps the public calendar identity stable across a first successful Google sync', async () => {
    const { service, google } = fixture();
    const before = (await service.listCalendars(de)).data[0]!.id;
    google.listCalendars.mockResolvedValue({ data: [], translationFallback: false });
    expect((await service.listCalendars(de)).data[0]!.id).toBe(before);
  });
  it('uses the current editorial Google link for the combined view rather than a retired import', async () => {
    const id = 'new-demo@group.calendar.google.com';
    const { service } = fixture({ ...calendar, googleShareUrl: share(id) });
    const url = new URL(await service.buildGoogleViewUrl(['demo'], de));
    expect(url.searchParams.getAll('src')).toEqual([id]);
    await expect(service.buildGoogleViewUrl([], de)).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
    });
  });
  it('uses the same public calendar identity in Google events and the catalogue', async () => {
    const { service } = fixture();
    const catalogue = await service.listCalendars(de);
    const result = await service.events(['demo'], from, to, de);
    expect(result.events.find((e) => e.source === 'google')?.calendarId).toBe(
      catalogue.data[0]!.id,
    );
  });
  it('falls back to the canonical entry when an English entry is malformed', async () => {
    const { service, get } = fixture({ ...calendar, googleShareUrl: null });
    get.mockImplementation(async (path, query) => ({
      data: path.includes('calendar-entries')
        ? [query.locale === 'en' ? { ...entry, title: '' } : entry]
        : [calendar],
      meta: { pagination: { pageCount: 1 } },
    }));
    const result = await service.events(['demo'], from, to, en);
    expect(result.events.some((e) => e.title === entry.title)).toBe(true);
    expect(result.translationFallback).toBe(true);
  });
  it('rejects a malformed pagination envelope instead of silently returning an incomplete list', async () => {
    const { service, get } = fixture();
    get.mockResolvedValue({ data: [calendar], meta: {} } as never);
    await expect(service.listCalendars(de)).rejects.toThrow();
  });
  it('bounds upstream pages and marks the result truncated', async () => {
    const { service, get } = fixture({ ...calendar, googleShareUrl: null });
    get.mockImplementation(async (path) => ({
      data: path.includes('calendar-entries')
        ? Array.from({ length: 100 }, (_, i) => ({
            ...entry,
            slug: `demo-${i}`,
            title: `Demo ${i}`,
          }))
        : [calendar],
      meta: { pagination: { pageCount: path.includes('calendar-entries') ? 100 : 1 } },
    }));
    const result = await service.events(['demo'], from, to, de);
    expect(result.truncated).toBe(true);
    expect(get.mock.calls.filter(([path]) => path.includes('calendar-entries'))).toHaveLength(1);
  });
  it('does not return editorial events outside the requested period even if upstream ignores its filters', async () => {
    const { service, get } = fixture({ ...calendar, googleShareUrl: null });
    get.mockImplementation(async (path) => ({
      data: path.includes('calendar-entries')
        ? [{ ...entry, start: '2026-12-16T10:00:00Z', end: '2026-12-16T11:00:00Z' }]
        : [calendar],
      meta: { pagination: { pageCount: 1 } },
    }));
    expect(
      (await service.events(['demo'], from, to, de)).events.filter((e) => e.source === 'editorial'),
    ).toEqual([]);
  });
});
