import { EditorialCalendarService } from './editorial-calendar.service';
import { Controller, Get, Inject, Param, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { ApiError } from '../../common/errors/api-error';
import { Locale, LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { isoDate, parseWith, refineDateRange } from '../../common/validation/query';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PublicCalendarService } from './public-calendar.service';
import { filterByLocation, parseLocationFilter } from '../locations/location';
import {
  GoogleViewUrlDataDto,
  GoogleViewUrlResponseDto,
  PublicCalendarDto,
  PublicCalendarEventDto,
  PublicCalendarEventsResponseDto,
  PublicCalendarListResponseDto,
} from './public-calendar.types';

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

@ApiTags('public-calendars')
@Controller({ path: 'calendars', version: '1' })
export class PublicCalendarController {
  /**
   * Built once, not per request.
   *
   * The schema depends on nothing but `PUBLIC_CALENDAR_API_MAX_RANGE_DAYS`, an
   * environment value that is fixed for the life of the process — but it used
   * to be constructed inside the request path, so every call to
   * `/v1/calendars/events` and `/v1/calendars/:slug/events` paid for building a
   * regex, three refinements and a transform before it validated anything.
   * Measured over 20.000 runs: 151,5 µs to build and parse against 2,5 µs to
   * parse alone. Every other query schema in this codebase is already a
   * constant; this one was the exception.
   */
  private readonly dateRange: ReturnType<typeof PublicCalendarController.buildDateRangeSchema>;

  constructor(
    private readonly calendars: PublicCalendarService,
    @Inject(ENV) private readonly env: Env,
    private readonly editorial?: EditorialCalendarService,
  ) {
    this.dateRange = PublicCalendarController.buildDateRangeSchema(
      env.PUBLIC_CALENDAR_API_MAX_RANGE_DAYS,
    );
  }

  private static buildDateRangeSchema(maxDays: number) {
    return refineDateRange(
      z.object({ from: isoDate.optional(), to: isoDate.optional() }).transform((raw) => {
        // Resolved at parse time, not at build time: the default window is
        // relative to "now", so it has to move with the clock.
        const today = new Date().toISOString().slice(0, 10);
        const from = raw.from ?? today;
        const to = raw.to ?? new Date(Date.now() + maxDays * 86_400_000).toISOString().slice(0, 10);
        return { from, to };
      }),
      maxDays,
    );
  }

  private parseCalendars(raw: unknown, locale: Locale): string[] {
    const values = Array.isArray(raw) ? raw : raw === undefined ? [] : [raw];
    const slugs: string[] = [];
    for (const v of values) {
      const s = String(v).trim();
      if (!SLUG_PATTERN.test(s)) {
        throw new ApiError('VALIDATION_FAILED', locale, [
          `calendar: invalid slug "${s.slice(0, 40)}"`,
        ]);
      }
      slugs.push(s);
    }
    const unique = [...new Set(slugs)];
    if (unique.length > this.env.PUBLIC_CALENDAR_API_MAX_CALENDARS) {
      throw new ApiError('VALIDATION_FAILED', locale, ['calendar: too many calendars requested']);
    }
    return unique;
  }

  private range(query: Record<string, unknown>, locale: Locale): { from: Date; to: Date } {
    const parsed = parseWith(this.dateRange, query, locale);
    return {
      from: new Date(`${parsed.from}T00:00:00.000Z`),
      to: new Date(`${parsed.to}T23:59:59.999Z`),
    };
  }

  @Get()
  @ApiOperation({
    summary: 'List channel calendars, with optional Google import.',
    description:
      'Active editorial calendars remain available without a Google sync. googleOpenUrl is an empty string for calendars without Google import. The Google calendar id and feed URL are never exposed.',
  })
  @ApiQuery({
    name: 'location',
    required: false,
    description:
      'One location slug from GET /v1/locations. Only calendars of that location are listed; calendars without a location are left out.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: PublicCalendarListResponseDto })
  async list(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown> = {},
  ): Promise<ApiResponse<PublicCalendarDto[]>> {
    return this.catalogue(locale, false, query);
  }

  @Get('all')
  @ApiOperation({
    summary: 'List every published, active calendar for websites, with or without a channel.',
    description:
      'Same fields and meta as GET /v1/calendars. Calendars without a channel are included; their channelSlug is an empty string and colorHex the default colour. Use the slugs with GET /v1/calendars/{slug}/entries.',
  })
  @ApiQuery({
    name: 'location',
    required: false,
    description:
      'One location slug from GET /v1/locations. Only calendars of that location are listed; calendars without a location are left out.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: PublicCalendarListResponseDto })
  async all(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown> = {},
  ): Promise<ApiResponse<PublicCalendarDto[]>> {
    return this.catalogue(locale, true, query);
  }

  private async catalogue(
    locale: LocaleResolution,
    includeUnmapped: boolean,
    query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarDto[]>> {
    const location = parseLocationFilter(query['location'], locale.resolvedLocale);
    const { data: calendars, translationFallback } = await (
      this.editorial ?? this.calendars
    ).listCalendars(locale, includeUnmapped);
    const now = Date.now();
    return {
      data: filterByLocation(calendars, location),
      meta: buildMeta({
        ...locale,
        translationFallback,
        featureEnabled: this.env.PUBLIC_CALENDAR_ENABLED,
        from: new Date(now).toISOString().slice(0, 10),
        to: new Date(now + this.env.PUBLIC_CALENDAR_LOOKAHEAD_DAYS * 86_400_000)
          .toISOString()
          .slice(0, 10),
        maxRangeDays: this.env.PUBLIC_CALENDAR_API_MAX_RANGE_DAYS,
        maxCalendars: this.env.PUBLIC_CALENDAR_API_MAX_CALENDARS,
      }),
    };
  }

  @Get('events')
  @ApiOperation({
    summary: 'Aggregated events across several selected public calendars.',
    description:
      'Pass one `calendar` slug per selected calendar. An empty selection returns an empty list (never "all calendars"). Each event carries calendarId and calendarSlug. The result is capped server-side; `meta.truncated` reports a cut list rather than presenting it as complete.',
  })
  @ApiQuery({ name: 'calendar', required: false, isArray: true, type: String })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: PublicCalendarEventsResponseDto })
  async aggregated(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarEventDto[]>> {
    const slugs = this.parseCalendars(query.calendar, locale.resolvedLocale);
    const range = this.range(query, locale.resolvedLocale);
    const { events, truncated, ...extra } = await (this.editorial
      ? this.editorial.events(slugs, range.from, range.to, locale)
      : this.calendars.getAggregatedEvents(slugs, range.from, range.to));
    return {
      data: events,
      meta: buildMeta({
        ...locale,
        translationFallback:
          'translationFallback' in extra ? (extra.translationFallback as boolean) : false,
        from: range.from.toISOString().slice(0, 10),
        to: range.to.toISOString().slice(0, 10),
        dataStale: 'dataStale' in extra ? (extra.dataStale as boolean) : false,
        truncated,
      }),
    };
  }

  @Get('google-view-url')
  @ApiOperation({
    summary: 'A combined calendar.google.com embed URL for the selected calendars.',
    description:
      "Server-constructed HTTPS URL (one src per calendar). This is a shared VIEW only — it never adds anything to a user's personal Google account.",
  })
  @ApiQuery({ name: 'calendar', required: true, isArray: true, type: String })
  @ApiOkResponse({ type: GoogleViewUrlResponseDto })
  async googleViewUrl(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<GoogleViewUrlDataDto>> {
    const slugs = this.parseCalendars(query.calendar, locale.resolvedLocale);
    const url = this.editorial
      ? await this.editorial.buildGoogleViewUrl(slugs, locale)
      : await this.calendars.buildGoogleViewUrl(slugs, locale.resolvedLocale);
    return { data: { url }, meta: buildMeta({ ...locale, translationFallback: false }) };
  }

  @Get(':slug/entries')
  @ApiOperation({
    summary:
      'Neutral calendar entries from editorial appointments, event posts and Google; editorial appointments win duplicates.',
  })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: PublicCalendarEventsResponseDto })
  async entries(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarEventDto[]>> {
    if (!SLUG_PATTERN.test(slug) || !this.editorial)
      throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    const range = this.range(query, locale.resolvedLocale);
    const catalogue = await this.editorial.listCalendars(locale, true);
    if (!catalogue.data.some((c) => c.slug === slug))
      throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    const result = await this.editorial.events([slug], range.from, range.to, locale, true);
    return {
      data: result.events,
      meta: buildMeta({
        ...locale,
        translationFallback: result.translationFallback,
        truncated: result.truncated,
        dataStale: result.dataStale,
        from: range.from.toISOString().slice(0, 10),
        to: range.to.toISOString().slice(0, 10),
      }),
    };
  }

  @Get(':slug/events')
  @ApiOperation({
    summary: 'Events of a single public calendar in a date range.',
    description:
      'The result is capped server-side; `meta.truncated` reports a cut list rather than presenting it as complete.',
  })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: PublicCalendarEventsResponseDto })
  async single(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarEventDto[]>> {
    if (!SLUG_PATTERN.test(slug))
      throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    const range = this.range(query, locale.resolvedLocale);
    const catalogue = this.editorial ? await this.editorial.listCalendars(locale) : null;
    const calendar = catalogue?.data.find((c) => c.slug === slug);
    const result = this.editorial
      ? calendar
        ? { calendar, ...(await this.editorial.events([slug], range.from, range.to, locale)) }
        : null
      : await this.calendars.getCalendarEvents(slug, range.from, range.to);
    if (!result) throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    return {
      data: result.events,
      meta: buildMeta({
        ...locale,
        translationFallback:
          'translationFallback' in result ? (result.translationFallback as boolean) : false,
        from: range.from.toISOString().slice(0, 10),
        to: range.to.toISOString().slice(0, 10),
        lastSuccessfulSyncAt: result.calendar.lastSuccessfulSyncAt,
        dataStale: result.calendar.dataStale,
        truncated: result.truncated,
      }),
    };
  }
}
