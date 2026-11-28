import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { TtlCache } from '../../common/cache/ttl-cache';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PostsService } from '../posts/posts.service';
import { StrapiClient } from '../strapi/strapi.client';
import { calendarPeriod, mergeCalendarEntries, parseEditorialEntry } from './calendar-entries';
import { PublicCalendarService, computeEventKey } from './public-calendar.service';
import { PublicCalendarDto, PublicCalendarEventDto } from './public-calendar.types';
import { CALENDAR_COLOR_PATTERN, effectiveCalendarColor } from './public-calendar.strapi';
import { LOCATION_POPULATE, mapLocationRef } from '../locations/location';
import {
  tryExtractCalendarId,
  buildSingleOpenUrl,
  buildCombinedEmbedUrl,
} from './google-calendar-url';

const calendarSchema = z.object({
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  name: z.string().min(1),
  colorHex: z.string().nullish().catch(null),
  googleShareUrl: z.string().nullish(),
  isActive: z.boolean(),
  sortOrder: z.number().int().default(0),
  defaultSubscribed: z.boolean().default(false),
  includeEventDescription: z.boolean().default(false),
  includeEventLocation: z.boolean().default(false),
  channel: z
    .object({ slug: z.string(), colorHex: z.string().regex(CALENDAR_COLOR_PATTERN) })
    .nullish(),
  // Validated by mapLocationRef: an unusable location must not drop the calendar.
  location: z.unknown().optional(),
});
const de: LocaleResolution = { requestedLocale: 'de', resolvedLocale: 'de' };

/** Editorial data stays in Strapi; the operational database holds only Google imports. */
@Injectable()
export class EditorialCalendarService {
  private readonly cache = new TtlCache<{ entries: unknown[]; truncated: boolean }>(30_000, 8);
  constructor(
    private readonly strapi: StrapiClient,
    private readonly google: PublicCalendarService,
    private readonly posts: PostsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private async read(path: string, query: Record<string, unknown>, limit = 10_000) {
    return this.cache.getOrSet(JSON.stringify([path, query, limit]), async () => {
      const entries: unknown[] = [];
      let bytes = 0;
      for (let page = 1; page <= 100; page++) {
        let raw: unknown;
        try {
          raw = await this.strapi.get(path, {
            ...query,
            status: 'published',
            pagination: { page, pageSize: Math.min(100, limit) },
          });
        } catch {
          throw new ApiError('UPSTREAM_UNAVAILABLE');
        }
        const parsed = z
          .object({
            data: z.array(z.unknown()),
            meta: z.object({
              pagination: z.object({ pageCount: z.number().int().min(0).max(100_000) }),
            }),
          })
          .safeParse(raw);
        if (!parsed.success) throw new ApiError('UPSTREAM_UNAVAILABLE');
        const response = parsed.data;
        const remaining = limit - entries.length;
        for (const entry of response.data.slice(0, remaining)) {
          bytes += Buffer.byteLength(JSON.stringify(entry));
          if (bytes > 2 * 1024 * 1024) return { entries, truncated: true };
          entries.push(entry);
        }
        const more = page < response.meta.pagination.pageCount || response.data.length > remaining;
        if (entries.length >= limit || !more) return { entries, truncated: more };
      }
      return { entries, truncated: true };
    });
  }

  async listCalendars(locale: LocaleResolution = de, includeUnmapped = false) {
    const raw = await this.read('/api/public-calendars', {
      locale: 'de',
      filters: { isActive: { $eq: true } },
      fields: [
        'slug',
        'name',
        'googleShareUrl',
        'colorHex',
        'isActive',
        'sortOrder',
        'defaultSubscribed',
        'includeEventDescription',
        'includeEventLocation',
      ],
      sort: ['sortOrder:asc', 'slug:asc'],
      populate: { channel: { fields: ['slug', 'colorHex'] }, location: LOCATION_POPULATE },
    });
    const imported = await this.google.listCalendars(locale, true);
    const translations =
      locale.resolvedLocale === 'en'
        ? await this.read('/api/public-calendars', {
            locale: 'en',
            filters: { isActive: { $eq: true } },
            fields: ['slug', 'name'],
          })
        : { entries: [], truncated: false };
    const names = new Map<string, string>();
    for (const entry of translations.entries) {
      const value = z.object({ slug: z.string(), name: z.string().min(1) }).safeParse(entry);
      if (value.success) names.set(value.data.slug, value.data.name);
    }
    if (raw.truncated || translations.truncated) throw new ApiError('UPSTREAM_UNAVAILABLE');
    const googleSources = new Map<
      string,
      { id: string; servable: boolean; description: boolean; location: boolean }
    >();
    let translationFallback = false;
    const data: PublicCalendarDto[] = [];
    for (const entry of raw.entries) {
      const parsed = calendarSchema.safeParse(entry);
      if (!parsed.success || !parsed.data.isActive) continue;
      const c = parsed.data;
      if (!c.channel && !includeUnmapped) continue; // Preserve the channel-only catalogue for existing clients.
      const google = c.googleShareUrl ? tryExtractCalendarId(c.googleShareUrl) : null;

      const cached = imported.data.find((v) => v.slug === c.slug);
      const importedSource = cached ? tryExtractCalendarId(cached.googleOpenUrl) : null;
      const matches =
        google?.ok && importedSource?.ok && google.calendarId === importedSource.calendarId;
      if (google?.ok)
        googleSources.set(c.slug, {
          id: google.calendarId,
          servable: !!matches,
          description: c.includeEventDescription,
          location: c.includeEventLocation,
        });
      const name = names.get(c.slug);
      if (locale.resolvedLocale === 'en' && !name) translationFallback = true;
      data.push({
        id: computeEventKey(c.slug, 'calendar'),
        slug: c.slug,
        channelSlug: c.channel?.slug ?? '',
        name: name ?? c.name,
        colorHex: effectiveCalendarColor(c.channel?.colorHex, c.colorHex),
        sortOrder: c.sortOrder,
        defaultSubscribed: c.defaultSubscribed,
        dataState: c.googleShareUrl ? (matches ? cached!.dataState : 'stale') : 'ready',
        dataStale: c.googleShareUrl ? (matches ? cached!.dataStale : true) : false,
        lastSuccessfulSyncAt: matches ? cached!.lastSuccessfulSyncAt : null,
        googleOpenUrl: google?.ok ? buildSingleOpenUrl(google.calendarId) : '',
        location: mapLocationRef(c.location),
      });
    }
    return { data, translationFallback, googleSources };
  }

  async buildGoogleViewUrl(slugs: string[], locale: LocaleResolution) {
    if (!slugs.length)
      throw new ApiError('VALIDATION_FAILED', locale.resolvedLocale, [
        'calendar: at least one calendar is required',
      ]);
    const catalogue = await this.listCalendars(locale, true);
    const ids = [...new Set(slugs)].flatMap((slug) => {
      const source = catalogue.googleSources.get(slug);
      return source ? [source.id] : [];
    });
    if (!ids.length) throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    return buildCombinedEmbedUrl(ids, this.env.PUBLIC_CALENDAR_FALLBACK_TIME_ZONE);
  }

  async events(
    slugs: string[],
    from: Date,
    to: Date,
    locale: LocaleResolution = de,
    includePosts = false,
  ) {
    if (!slugs.length) return { events: [], truncated: false, translationFallback: false };
    const catalogue = await this.listCalendars(locale, true);
    const selected = catalogue.data.filter((c) => slugs.includes(c.slug));
    const google = await this.google.getAggregatedEvents(
      selected.filter((c) => catalogue.googleSources.get(c.slug)?.servable).map((c) => c.slug),
      from,
      to,
      Object.fromEntries([...catalogue.googleSources].map(([slug, source]) => [slug, source.id])),
    );
    let translationFallback = catalogue.translationFallback;
    const entries: PublicCalendarEventDto[] = google.events
      .filter(
        (e) =>
          selected.some((c) => c.slug === e.calendarSlug) &&
          catalogue.googleSources.get(e.calendarSlug)?.servable,
      )
      .map((e) => ({
        ...e,
        calendarId: selected.find((c) => c.slug === e.calendarSlug)!.id,
        description: catalogue.googleSources.get(e.calendarSlug)?.description
          ? e.description
          : null,
        location: catalogue.googleSources.get(e.calendarSlug)?.location ? e.location : null,
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
      populate: {
        calendar: { fields: ['slug'] },
        image: { fields: ['url', 'mime'] },
        attachments: { fields: ['url', 'name', 'mime'] },
        links: true,
      },
    };
    let editorialTruncated = false;
    if (selected.length) {
      const canonical = await this.read(
        '/api/calendar-entries',
        { ...query, locale: 'de' },
        this.env.PUBLIC_CALENDAR_API_MAX_EVENTS + 1,
      );
      const translated =
        locale.resolvedLocale === 'en'
          ? await this.read(
              '/api/calendar-entries',
              { ...query, locale: 'en' },
              this.env.PUBLIC_CALENDAR_API_MAX_EVENTS + 1,
            )
          : { entries: [], truncated: false };
      editorialTruncated = canonical.truncated || translated.truncated;
      const bySlug = new Map<string, Record<string, unknown>>();
      for (const raw of translated.entries) {
        const v = z.object({ slug: z.string() }).passthrough().safeParse(raw);
        if (v.success) bySlug.set(v.data.slug, v.data);
      }
      for (const raw of canonical.entries) {
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
        let mapped = parseEditorialEntry(value, c.slug, c.id);
        if (!mapped && en) {
          mapped = parseEditorialEntry(raw, c.slug, c.id);
          translationFallback = true;
        }
        if (
          mapped &&
          Date.parse(mapped.start) <= to.getTime() &&
          Date.parse(mapped.end) > from.getTime()
        )
          entries.push(mapped);
      }
    }
    let truncated = google.truncated || editorialTruncated;
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
          if (
            !c ||
            !post.eventStart ||
            !Number.isFinite(Date.parse(post.eventStart)) ||
            (post.eventEnd != null &&
              (!Number.isFinite(Date.parse(post.eventEnd)) ||
                Date.parse(post.eventEnd) < Date.parse(post.eventStart)))
          )
            continue;
          entries.push({
            id: computeEventKey(c.slug, `post:${post.slug}`),
            calendarId: c.id,
            calendarSlug: c.slug,
            title: post.title,
            description: JSON.stringify(post.content) === '[]' ? null : plainText(post.content),
            location: null,
            ...calendarPeriod(post.eventStart, post.eventEnd ?? post.eventStart, post.eventAllDay),
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
      dataStale: selected.some((calendar) => calendar.dataStale),
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
