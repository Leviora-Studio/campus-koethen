import { EditorialCalendarService } from './editorial-calendar.service';
import { StrapiClient } from '../strapi/strapi.client';
import { PublicCalendarService } from './public-calendar.service';
import { PostsService } from '../posts/posts.service';
import { Env } from '../../config/env.schema';

const locale = { requestedLocale: 'de' as const, resolvedLocale: 'de' as const };
const calendar = {
  slug: 'demo',
  name: 'Demo calendar',
  isActive: true,
  googleShareUrl: null,
  channel: { slug: 'demo-channel', colorHex: '#123456' },
};
const appointment = {
  slug: 'demo-appointment',
  title: 'Demo appointment',
  start: '2026-11-16T10:00:00Z',
  end: '2026-11-16T11:00:00Z',
  timeZone: 'Europe/Berlin',
  calendar: { slug: 'demo' },
};
function fixture() {
  const get = jest.fn(async (path: string) => ({
    data: path.includes('calendar-entries') ? [appointment] : [calendar],
    meta: { pagination: { pageCount: 1 } },
  }));
  const google = {
    listCalendars: jest.fn(async () => ({ data: [], translationFallback: false })),
    getAggregatedEvents: jest.fn(async () => ({ events: [], truncated: false })),
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
    { PUBLIC_CALENDAR_API_MAX_EVENTS: 100 } as Env,
  );
  return { service, get, google, posts };
}
describe('editorial calendars', () => {
  it('serves a calendar and its appointments without any Google sync', async () => {
    const { service, google } = fixture();
    expect((await service.listCalendars(locale)).data[0]).toMatchObject({
      slug: 'demo',
      googleOpenUrl: '',
      dataStale: false,
    });
    const result = await service.events(
      ['demo'],
      new Date('2026-11-16'),
      new Date('2026-11-17'),
      locale,
    );
    expect(result.events).toHaveLength(1);
    expect(result.events[0]).toMatchObject({ source: 'editorial', title: 'Demo appointment' });
    expect(google.getAggregatedEvents).toHaveBeenCalledWith([], expect.any(Date), expect.any(Date));
  });
  it('never queries all editorial entries for an empty selection', async () => {
    const { service, get } = fixture();
    expect((await service.events([], new Date(), new Date(), locale)).events).toEqual([]);
    expect(get).not.toHaveBeenCalled();
  });
  it('merges all three sources, with the editorial appointment winning', async () => {
    const { service, google, posts } = fixture();
    const post = {
      slug: 'demo-post',
      title: appointment.title,
      eventStart: appointment.start,
      eventEnd: appointment.end,
      eventAllDay: false,
      primaryChannel: { slug: 'another-demo-channel' },
      channels: [{ slug: 'demo-channel' }],
      content: [],
      heroImage: null,
    };
    posts.getEvents.mockResolvedValue({
      data: [post],
      pagination: { totalPages: 1 },
      translationFallback: false,
    } as never);
    google.getAggregatedEvents.mockResolvedValue({
      events: [
        {
          id: 'google',
          calendarId: 'demo-id',
          calendarSlug: 'demo',
          title: appointment.title,
          start: appointment.start,
          end: appointment.end,
          allDay: false,
          status: 'confirmed',
        },
      ],
      truncated: false,
    } as never);
    const result = await service.events(
      ['demo'],
      new Date('2026-11-16'),
      new Date('2026-11-17'),
      locale,
      true,
    );
    expect(result.events).toHaveLength(1);
    expect(result.events[0]?.source).toBe('editorial');
  });
});
