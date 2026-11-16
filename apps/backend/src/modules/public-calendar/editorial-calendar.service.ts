import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { TtlCache } from '../../common/cache/ttl-cache';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PostsService } from '../posts/posts.service';
import { StrapiClient, StrapiListResponse } from '../strapi/strapi.client';
import { mergeCalendarEntries, parseEditorialEntry } from './calendar-entries';
import { PublicCalendarService, computeEventKey } from './public-calendar.service';
import { PublicCalendarDto, PublicCalendarEventDto } from './public-calendar.types';
import { tryExtractCalendarId, buildSingleOpenUrl } from './google-calendar-url';

const calendarSchema = z.object({
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  name: z.string().min(1),
  googleShareUrl: z.string().nullish(),
  isActive: z.boolean(),
  sortOrder: z.number().int().default(0),
  defaultSubscribed: z.boolean().default(false),
  channel: z
    .object({ slug: z.string(), colorHex: z.string().regex(/^#[0-9a-fA-F]{6}$/) })
    .nullish(),
});
const de: LocaleResolution = { requestedLocale: 'de', resolvedLocale: 'de' };

/** Editorial data stays in Strapi; the operational database holds only Google imports. */
@Injectable()
export class EditorialCalendarService {
  private readonly cache = new TtlCache<unknown[]>(30_000);
  constructor(
    private readonly strapi: StrapiClient,
    private readonly google: PublicCalendarService,
    private readonly posts: PostsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private async read(path: string, query: Record<string, unknown>): Promise<unknown[]> {
    return this.cache.getOrSet(JSON.stringify([path, query]), async () => {
      const entries: unknown[] = [];
      for (let page = 1; page <= 100; page++) {
        const response = await this.strapi.get<StrapiListResponse<unknown>>(path, {
          ...query,
          status: 'published',
          pagination: { page, pageSize: 100 },
        });
        if (!Array.isArray(response.data)) throw new ApiError('UPSTREAM_UNAVAILABLE');
        entries.push(...response.data);
        if (page >= (response.meta?.pagination?.pageCount ?? 1)) return entries;
      }
      throw new ApiError('UPSTREAM_UNAVAILABLE');
    });
  }

  async listCalendars(locale: LocaleResolution = de, includeUnmapped = false) {
    const raw = await this.read('/api/public-calendars', {
      locale: 'de',
      filters: { isActive: { $eq: true } },
      sort: ['sortOrder:asc', 'slug:asc'],
      populate: { channel: { fields: ['slug', 'colorHex'] } },
    });
    const imported = await this.google.listCalendars(locale, true);
    const translations =
      locale.resolvedLocale === 'en'
        ? await this.read('/api/public-calendars', {
            locale: 'en',
            filters: { isActive: { $eq: true } },
            fields: ['slug', 'name'],
          })
        : [];
    const names = new Map<string, string>();
    for (const entry of translations) {
      const value = z.object({ slug: z.string(), name: z.string().min(1) }).safeParse(entry);
      if (value.success) names.set(value.data.slug, value.data.name);
    }
    let translationFallback = false;
    const data: PublicCalendarDto[] = [];
    for (const entry of raw) {
      const parsed = calendarSchema.safeParse(entry);
      if (!parsed.success || !parsed.data.isActive) continue;
      const c = parsed.data;
      if (!c.channel && !includeUnmapped) continue; // App catalogue remains channel-based.
      const google = c.googleShareUrl ? tryExtractCalendarId(c.googleShareUrl) : null;
      if (c.googleShareUrl && !google?.ok) continue;
      const cached = imported.data.find((v) => v.slug === c.slug);
      const name = names.get(c.slug);
      if (locale.resolvedLocale === 'en' && !name) translationFallback = true;
      data.push({
        id: cached?.id ?? computeEventKey(c.slug, 'calendar'),
        slug: c.slug,
        channelSlug: c.channel?.slug ?? '',
        name: name ?? c.name,
        colorHex: c.channel?.colorHex ?? '#5B3FD0',
        sortOrder: c.sortOrder,
        defaultSubscribed: c.defaultSubscribed,
        dataState: google?.ok ? (cached?.dataState ?? 'stale') : 'ready',
        dataStale: google?.ok ? (cached?.dataStale ?? true) : false,
        lastSuccessfulSyncAt: cached?.lastSuccessfulSyncAt ?? null,
        googleOpenUrl: google?.ok ? buildSingleOpenUrl(google.calendarId) : '',
      });
    }
    return { data, translationFallback };
  }

  async events(
    slugs: string[],
    from: Date,
    to: Date,
    locale: LocaleResolution = de,
    includePosts = false,
  ) {
    if (!slugs.length) return { events: [], truncated: false, translationFallback: false };
    const catalogue = await this.listCalendars(locale, includePosts);
    const selected = catalogue.data.filter((c) => slugs.includes(c.slug));
    const google = await this.google.getAggregatedEvents(
      selected.filter((c) => c.googleOpenUrl).map((c) => c.slug),
      from,
      to,
    );
    let translationFallback = catalogue.translationFallback;
    const entries: PublicCalendarEventDto[] = google.events.map((e) => ({
      ...e,
      source: 'google',
      timeZone: null,
      imageUrl: null,
      links: [],
      attachments: [],
    }));
    const query = {
      filters: {
        calendar: { slug: { $in: selected.map((c) => c.slug) } },
        start: { $lte: to.toISOString() },
        end: { $gte: from.toISOString() },
      },
      sort: ['start:asc', 'slug:asc'],
      populate: { calendar: { fields: ['slug'] }, image: true, attachments: true, links: true },
    };
    if (selected.length) {
      const canonical = await this.read('/api/calendar-entries', { ...query, locale: 'de' });
      const translated =
        locale.resolvedLocale === 'en'
          ? await this.read('/api/calendar-entries', { ...query, locale: 'en' })
          : [];
      const bySlug = new Map<string, Record<string, unknown>>();
      for (const raw of translated) {
        const v = z.object({ slug: z.string() }).passthrough().safeParse(raw);
        if (v.success) bySlug.set(v.data.slug, v.data);
      }
      for (const raw of canonical) {
        const relation = z
          .object({ slug: z.string(), calendar: z.object({ slug: z.string() }) })
          .passthrough()
          .safeParse(raw);
        if (!relation.success) continue;
        const c = selected.find((v) => v.slug === relation.data.calendar.slug);
        if (!c) continue;
        const en = bySlug.get(relation.data.slug);
        if (locale.resolvedLocale === 'en' && !en) translationFallback = true;
        const value = en
          ? {
              ...relation.data,
              title: en.title,
              description: en.description,
              location: en.location,
              links: en.links,
            }
          : raw;
        const mapped = parseEditorialEntry(value, c.slug, c.id);
        if (mapped) entries.push(mapped);
      }
    }
    let truncated = google.truncated;
    if (includePosts && selected.some((c) => c.channelSlug)) {
      for (let page = 1; page <= 100; page++) {
        const result = await this.posts.getEvents(locale, {
          from: from.toISOString().slice(0, 10),
          to: to.toISOString().slice(0, 10),
          channels: selected.map((c) => c.channelSlug).filter(Boolean),
          channelsParamPresent: true,
          page,
          pageSize: 100,
        });
        translationFallback ||= result.translationFallback;
        for (const post of result.data) {
          const c = selected.find(
            (v) =>
              v.channelSlug === post.primaryChannel.slug ||
              (post.channels ?? []).some((channel) => channel.slug === v.channelSlug),
          );
          if (!c || !post.eventStart) continue;
          entries.push({
            id: computeEventKey(c.slug, `post:${post.slug}`),
            calendarId: c.id,
            calendarSlug: c.slug,
            title: post.title,
            description: JSON.stringify(post.content) === '[]' ? null : plainText(post.content),
            location: null,
            start: post.eventStart,
            end: post.eventEnd ?? post.eventStart,
            allDay: post.eventAllDay,
            status: 'confirmed',
            source: 'post',
            timeZone: null,
            imageUrl: post.heroImage?.url ?? null,
            links: [],
            attachments: [],
          });
        }
        if (page >= result.pagination.totalPages) break;
        if (page === 100) truncated = true;
      }
    }
    const merged = mergeCalendarEntries(entries);
    const limit = this.env.PUBLIC_CALENDAR_API_MAX_EVENTS;
    return {
      events: merged.slice(0, limit),
      truncated: truncated || merged.length > limit,
      translationFallback,
    };
  }
}

function plainText(value: unknown): string {
  if (Array.isArray(value)) return value.map(plainText).filter(Boolean).join(' ');
  if (value && typeof value === 'object') {
    const node = value as Record<string, unknown>;
    return typeof node.text === 'string' ? node.text : plainText(node.children);
  }
  return '';
}
