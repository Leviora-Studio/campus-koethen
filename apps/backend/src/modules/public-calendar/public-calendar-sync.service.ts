import { z } from 'zod';
import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { StrapiClient, StrapiListResponse } from '../strapi/strapi.client';
import { GooglePublicIcsClient, IcsClientError } from './google-public-ics.client';
import { IcsParseError, ParsedEvent, parseIcs } from './ics-parser';
import { CalendarDefinition } from './public-calendar.types';
import { validateCatalog } from './public-calendar.strapi';

/**
 * Public-calendar synchronisation.
 *
 * Two independent jobs, both governed by the project's core rule: a failed,
 * invalid or unexpectedly empty upstream response NEVER deletes stored data.
 *
 *  - `syncCatalog()` mirrors the PUBLISHED, VALIDATED Strapi definitions into
 *    the operational read-model. Strapi stays the canonical editorial source;
 *    Postgres only ever holds the last fully-validated snapshot.
 *  - `syncEvents()` downloads each active calendar's public ICS feed, expands
 *    it within a bounded window and reconciles it transactionally. A calendar
 *    becomes publicly visible only after validation AND a first successful sync.
 */

export interface CatalogOutcome {
  status: 'success' | 'empty' | 'failed';
  received: number;
  accepted: number;
  rejected: number;
  written: number;
  deactivated: number;
  errorCode?: string;
}

export interface EventOutcome {
  slug: string;
  status: 'success' | 'notModified' | 'empty' | 'stale' | 'revoked' | 'failed';
  received: number;
  written: number;
  removed: number;
  errorCode?: string;
}

type SyncDefinition = {
  id: string;
  googleCalendarId: string;
  includeEventDescription: boolean;
  includeEventLocation: boolean;
  lastSuccessfulSyncAt: Date | null;
};
class CalendarDefinitionChanged extends Error {}
function expectedDefinition(calendar: SyncDefinition) {
  return {
    id: calendar.id,
    isActive: true,
    googleCalendarId: calendar.googleCalendarId,
    includeEventDescription: calendar.includeEventDescription,
    includeEventLocation: calendar.includeEventLocation,
    lastSuccessfulSyncAt: calendar.lastSuccessfulSyncAt,
  };
}

@Injectable()
export class PublicCalendarSyncService {
  private readonly logger = new Logger(PublicCalendarSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly strapi: StrapiClient,
    private readonly ics: GooglePublicIcsClient,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // -------------------------------------------------------------------------
  // Catalogue
  // -------------------------------------------------------------------------

  async syncCatalog(): Promise<CatalogOutcome> {
    const run = await this.prisma.publicCalendarSyncRun.create({
      data: { kind: 'catalog', status: 'running' },
    });
    try {
      const [de, en] = await Promise.all([this.fetchAll('de'), this.fetchAll('en')]);
      const { definitions, received, rejected, editorialOnlySlugs } = validateCatalog(de, en);

      // An empty (or fully-rejected) catalogue is treated as suspect: it keeps
      // the last good read-model instead of deactivating every calendar.
      if (definitions.length === 0) {
        if (editorialOnlySlugs.length && !rejected) {
          const stopped = await this.prisma.publicCalendar.updateMany({
            where: { slug: { in: editorialOnlySlugs }, isActive: true },
            data: { isActive: false },
          });
          await this.finishRun(run.id, {
            status: 'success',
            eventsReceived: received,
            recordsRemoved: stopped.count,
          });
          return {
            status: 'success',
            received,
            accepted: 0,
            rejected: 0,
            written: 0,
            deactivated: stopped.count,
          };
        }
        await this.finishRun(run.id, {
          status: 'empty',
          eventsReceived: received,
          recordsRejected: rejected,
          errorMessage: 'empty or fully-rejected catalogue; existing definitions kept',
        });
        this.logger.warn('Public-calendar catalogue came back empty; existing definitions kept');
        return { status: 'empty', received, accepted: 0, rejected, written: 0, deactivated: 0 };
      }

      // A channel has at most one calendar. Keep the first (Strapi's own sort
      // order) and drop duplicates. Independent calendars are not duplicates.
      const seenChannelSlugs = new Set<string>();
      const accepted = definitions.filter((def) => {
        if (def.channelSlug === null) return true;
        if (!seenChannelSlugs.has(def.channelSlug)) {
          seenChannelSlugs.add(def.channelSlug);
          return true;
        }
        this.logger.warn({
          message: `Duplicate channelSlug "${def.channelSlug}" on calendar "${def.slug}". Keeping earlier assignment; dropping this calendar.`,
          channelSlug: def.channelSlug,
          calendarSlug: def.slug,
        });
        return false;
      });
      const duplicates = definitions.length - accepted.length;

      const now = new Date();
      const retired = await this.prisma.$transaction(async (tx) => {
        for (const def of accepted) {
          const previous = await tx.publicCalendar.findUnique({ where: { slug: def.slug } });
          const reset =
            previous &&
            (previous.googleCalendarId !== def.googleCalendarId ||
              previous.includeEventDescription !== def.includeEventDescription ||
              previous.includeEventLocation !== def.includeEventLocation);
          await tx.publicCalendar.upsert({
            where: { slug: def.slug },
            create: { ...this.toRow(def), operationalStatus: 'pending', lastCatalogSyncAt: now },
            update: {
              ...this.toRow(def),
              isActive: true,
              lastCatalogSyncAt: now,
              ...(reset
                ? {
                    operationalStatus: 'pending',
                    lastSuccessfulSyncAt: null,
                    lastEtag: null,
                    lastModified: null,
                    lastContentHash: null,
                  }
                : {}),
            },
          });
        }
        // A partially invalid catalogue cannot prove that an existing calendar was removed.
        return rejected > 0
          ? { count: 0 }
          : tx.publicCalendar.updateMany({
              where: { isActive: true, slug: { notIn: accepted.map((d) => d.slug) } },
              data: { isActive: false },
            });
      });

      await this.finishRun(run.id, {
        status: 'success',
        eventsReceived: received,
        recordsAccepted: accepted.length,
        recordsRejected: rejected + duplicates,
        recordsWritten: accepted.length,
        recordsRemoved: retired.count,
      });
      this.logger.log(
        `Public-calendar catalogue: ${accepted.length} upserted, ${retired.count} retired, ${rejected + duplicates} rejected`,
      );
      return {
        status: 'success',
        received,
        accepted: accepted.length,
        rejected: rejected + duplicates,
        written: accepted.length,
        deactivated: retired.count,
      };
    } catch (error) {
      const code = error instanceof Error ? error.name : 'unknown';
      await this.finishRun(run.id, {
        status: 'failed',
        errorCode: 'strapiUnavailable',
        errorMessage: this.redact(error),
      });
      this.logger.warn(
        `Public-calendar catalogue sync failed (${code}); existing definitions kept`,
      );
      return {
        status: 'failed',
        received: 0,
        accepted: 0,
        rejected: 0,
        written: 0,
        deactivated: 0,
        errorCode: code,
      };
    }
  }

  private toRow(def: CalendarDefinition) {
    return {
      slug: def.slug,
      googleCalendarId: def.googleCalendarId,
      channelSlug: def.channelSlug,
      nameDe: def.nameDe,
      nameEn: def.nameEn,
      colorHex: def.colorHex,
      sortOrder: def.sortOrder,
      defaultSubscribed: def.defaultSubscribed,
      includeEventDescription: def.includeEventDescription,
      includeEventLocation: def.includeEventLocation,
    };
  }

  private async fetchAll(locale: 'de' | 'en'): Promise<unknown[]> {
    const collected: unknown[] = [];
    let page = 1;
    for (; page <= 100;) {
      const response = await this.strapi.get<StrapiListResponse<unknown>>('/api/public-calendars', {
        filters: { isActive: { $eq: true } },
        sort: ['sortOrder:asc', 'slug:asc'],
        pagination: { page, pageSize: 100 },
        populate: { channel: { fields: ['slug', 'colorHex'] } },
        locale,
      });
      const parsed = z
        .object({
          data: z.array(z.unknown()),
          meta: z.object({ pagination: z.object({ pageCount: z.number().int().min(0).max(100) }) }),
        })
        .parse(response);
      collected.push(...parsed.data);
      const pageCount = parsed.meta.pagination.pageCount;
      if (page >= pageCount) break;
      page += 1;
    }
    if (page > 100) throw new Error('Calendar catalogue page limit exceeded');
    return collected;
  }

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  window(now = new Date()): { from: Date; to: Date } {
    const day = 86_400_000;
    return {
      from: new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) -
          this.env.PUBLIC_CALENDAR_LOOKBACK_DAYS * day,
      ),
      to: new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) +
          (this.env.PUBLIC_CALENDAR_LOOKAHEAD_DAYS + 1) * day -
          1,
      ),
    };
  }

  async syncEvents(): Promise<EventOutcome[]> {
    // Only the slug: `syncCalendarEvents` reads the row it needs itself, so
    // selecting the whole record here meant pulling every calendar twice per
    // run — including `lastEtag`, `lastModified` and `lastContentHash`, the
    // columns that carry the most text — and discarding the first copy.
    const calendars = await this.prisma.publicCalendar.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: { slug: true },
    });
    // Each calendar is isolated: one failing feed never stops the others.
    return Promise.all(calendars.map((calendar) => this.syncCalendarEvents(calendar.slug)));
  }

  async syncCalendarEvents(slug: string): Promise<EventOutcome> {
    const calendar = await this.prisma.publicCalendar.findUnique({ where: { slug } });
    if (!calendar || !calendar.isActive) {
      return {
        slug,
        status: 'failed',
        received: 0,
        written: 0,
        removed: 0,
        errorCode: 'unknownCalendar',
      };
    }

    const win = this.window();
    const run = await this.prisma.publicCalendarSyncRun.create({
      data: {
        kind: 'events',
        status: 'running',
        calendarSlug: slug,
        rangeFrom: win.from,
        rangeTo: win.to,
      },
    });

    try {
      const refreshWindow =
        !calendar.lastSuccessfulSyncAt ||
        calendar.lastSuccessfulSyncAt.toISOString().slice(0, 10) !==
          new Date().toISOString().slice(0, 10);
      const fetched = await this.ics.fetchCalendar(calendar.googleCalendarId, {
        etag: refreshWindow ? null : calendar.lastEtag,
        lastModified: refreshWindow ? null : calendar.lastModified,
      });

      if (fetched.kind === 'notModified') {
        if (refreshWindow)
          throw new IcsParseError(
            'invalidCalendar',
            'Unexpected 304 for an unconditional window refresh',
          );
        const updated = await this.prisma.publicCalendar.updateMany({
          where: expectedDefinition(calendar),
          data: { lastSuccessfulSyncAt: new Date(), operationalStatus: 'ready' },
        });
        if (!updated.count) throw new CalendarDefinitionChanged();
        await this.finishRun(run.id, { status: 'notModified' });
        return { slug, status: 'notModified', received: 0, written: 0, removed: 0 };
      }

      const contentHash = createHash('sha256').update(fetched.body).digest('hex');
      if (!refreshWindow && contentHash === calendar.lastContentHash) {
        const updated = await this.prisma.publicCalendar.updateMany({
          where: expectedDefinition(calendar),
          data: {
            lastSuccessfulSyncAt: new Date(),
            operationalStatus: 'ready',
            lastEtag: fetched.etag,
            lastModified: fetched.lastModified,
          },
        });
        if (!updated.count) throw new CalendarDefinitionChanged();
        await this.finishRun(run.id, { status: 'notModified', feedBytes: fetched.body.length });
        return { slug, status: 'notModified', received: 0, written: 0, removed: 0 };
      }

      const events = parseIcs(fetched.body, {
        windowStart: win.from,
        windowEnd: win.to,
        fallbackTimeZone: this.env.PUBLIC_CALENDAR_FALLBACK_TIME_ZONE,
        includeDescription: calendar.includeEventDescription,
        includeLocation: calendar.includeEventLocation,
        maxEvents: this.env.PUBLIC_CALENDAR_MAX_EVENTS,
        maxOccurrences: this.env.PUBLIC_CALENDAR_MAX_OCCURRENCES,
        maxOccurrencesPerEvent: this.env.PUBLIC_CALENDAR_MAX_OCCURRENCES_PER_EVENT,
        maxScannedOccurrences: this.env.PUBLIC_CALENDAR_MAX_SCANNED_OCCURRENCES,
        maxTextLength: this.env.PUBLIC_CALENDAR_MAX_TEXT_LENGTH,
      });

      if (
        !events.length &&
        (await this.prisma.publicCalendarEvent.count({ where: { calendarId: calendar.id } }))
      ) {
        throw new IcsParseError(
          'invalidCalendar',
          'Empty feed cannot replace the last successful event stock',
        );
      }
      const removed = await this.reconcile(calendar.id, win, events, calendar, {
        operationalStatus: 'ready',
        lastEtag: fetched.etag,
        lastModified: fetched.lastModified,
        lastContentHash: contentHash,
        lastSuccessfulSyncAt: new Date(),
      });
      await this.finishRun(run.id, {
        status: events.length === 0 ? 'empty' : 'success',
        feedBytes: fetched.body.length,
        eventsExpanded: events.length,
        recordsWritten: events.length,
        recordsRemoved: removed,
      });
      return {
        slug,
        status: events.length === 0 ? 'empty' : 'success',
        received: events.length,
        written: events.length,
        removed,
      };
    } catch (error) {
      if (error instanceof CalendarDefinitionChanged) {
        await this.finishRun(run.id, { status: 'failed', errorCode: 'definitionChanged' });
        return {
          slug,
          status: 'failed',
          received: 0,
          written: 0,
          removed: 0,
          errorCode: 'definitionChanged',
        };
      }
      return this.handleEventFailure(
        run.id,
        calendar.id,
        slug,
        calendar.operationalStatus,
        calendar.lastSuccessfulSyncAt,
        error,
        calendar,
      );
    }
  }

  /** True when the feed carries anything the stored occurrence does not already say. */
  private static occurrenceChanged(
    stored: {
      uid: string;
      recurrenceId: string | null;
      sequence: number | null;
      title: string;
      description: string | null;
      location: string | null;
      startsAt: Date;
      endsAt: Date;
      allDay: boolean;
      status: string;
      sourceUpdatedAt: Date | null;
    },
    next: ParsedEvent,
  ): boolean {
    return (
      stored.uid !== next.uid ||
      stored.recurrenceId !== next.recurrenceId ||
      stored.sequence !== next.sequence ||
      stored.title !== next.title ||
      stored.description !== next.description ||
      stored.location !== next.location ||
      stored.startsAt.getTime() !== next.start.getTime() ||
      stored.endsAt.getTime() !== next.end.getTime() ||
      stored.allDay !== next.allDay ||
      stored.status !== next.status ||
      (stored.sourceUpdatedAt?.getTime() ?? null) !== (next.sourceUpdatedAt?.getTime() ?? null)
    );
  }

  /**
   * Transactional, windowed, non-destructive reconciliation.
   *
   * Only reached when the feed body actually changed, and what changes in a
   * feed is normally one appointment — while an expanded window can hold
   * thousands of occurrences (PUBLIC_CALENDAR_MAX_OCCURRENCES). Writing every
   * one of them back to record a single move cost a round-trip and a row
   * update each, all inside one transaction. So the stored window is read once
   * and only the genuine differences are written; everything else just gets the
   * same `lastSeenAt` stamp the upsert wrote, in one statement.
   */
  private async reconcile(
    calendarId: string,
    win: { from: Date; to: Date },
    events: ParsedEvent[],
    expected: SyncDefinition,
    syncData: {
      operationalStatus: string;
      lastEtag: string | null;
      lastModified: string | null;
      lastContentHash: string;
      lastSuccessfulSyncAt: Date;
    },
  ): Promise<number> {
    return this.prisma.$transaction(
      async (tx) => {
        // Locks the current definition until the occurrences and sync metadata commit together.
        const updated = await tx.publicCalendar.updateMany({
          where: expectedDefinition(expected),
          data: syncData,
        });
        if (!updated.count) throw new CalendarDefinitionChanged();
        const keptKeys = events.map((event) => event.occurrenceKey);
        const now = new Date();

        const stored = await tx.publicCalendarEvent.findMany({
          where: { calendarId, occurrenceKey: { in: keptKeys } },
          select: {
            id: true,
            occurrenceKey: true,
            uid: true,
            recurrenceId: true,
            sequence: true,
            title: true,
            description: true,
            location: true,
            startsAt: true,
            endsAt: true,
            allDay: true,
            status: true,
            sourceUpdatedAt: true,
          },
        });
        const storedByKey = new Map(stored.map((row) => [row.occurrenceKey, row]));

        const toCreate: ParsedEvent[] = [];
        const toUpdate: ParsedEvent[] = [];
        const unchangedIds: string[] = [];

        for (const event of events) {
          const row = storedByKey.get(event.occurrenceKey);
          if (!row) {
            toCreate.push(event);
          } else if (PublicCalendarSyncService.occurrenceChanged(row, event)) {
            toUpdate.push(event);
          } else {
            unchangedIds.push(row.id);
          }
        }

        if (toCreate.length > 0) {
          await tx.publicCalendarEvent.createMany({
            data: toCreate.map((event) => ({
              calendarId,
              occurrenceKey: event.occurrenceKey,
              uid: event.uid,
              recurrenceId: event.recurrenceId,
              sequence: event.sequence,
              title: event.title,
              description: event.description,
              location: event.location,
              startsAt: event.start,
              endsAt: event.end,
              allDay: event.allDay,
              status: event.status,
              sourceUpdatedAt: event.sourceUpdatedAt,
            })),
          });
        }

        for (const event of toUpdate) {
          await tx.publicCalendarEvent.update({
            where: {
              calendarId_occurrenceKey: { calendarId, occurrenceKey: event.occurrenceKey },
            },
            data: {
              uid: event.uid,
              recurrenceId: event.recurrenceId,
              sequence: event.sequence,
              title: event.title,
              description: event.description,
              location: event.location,
              startsAt: event.start,
              endsAt: event.end,
              allDay: event.allDay,
              status: event.status,
              sourceUpdatedAt: event.sourceUpdatedAt,
              lastSeenAt: now,
            },
          });
        }

        if (unchangedIds.length > 0) {
          await tx.publicCalendarEvent.updateMany({
            where: { id: { in: unchangedIds } },
            data: { lastSeenAt: now },
          });
        }

        // Delete only WITHIN the confirmed window and only rows not seen this run.
        const removed = await tx.publicCalendarEvent.deleteMany({
          where: {
            calendarId,
            startsAt: { gte: win.from, lte: win.to },
            occurrenceKey: { notIn: keptKeys.length > 0 ? keptKeys : ['__none__'] },
          },
        });
        return removed.count;
      },
      { timeout: 120_000, maxWait: 10_000 },
    );
  }

  private async handleEventFailure(
    runId: string,
    calendarId: string,
    slug: string,
    currentStatus: string,
    hadSuccess: Date | null,
    error: unknown,
    expected: SyncDefinition,
  ): Promise<EventOutcome> {
    let errorCode = 'unknown';
    let nextStatus = currentStatus;
    let runStatus: EventOutcome['status'] = 'failed';

    if (error instanceof IcsClientError) {
      errorCode = error.kind;
      if (error.kind === 'feedNotFound' || error.kind === 'permissionRevoked') {
        // The feed is gone / no longer public: block it and clear its events so
        // stale data is not served indefinitely.
        nextStatus = error.kind === 'feedNotFound' ? 'unavailable' : 'revoked';
        runStatus = 'revoked';
      } else {
        // Temporary transport error: keep the last good events, mark stale.
        nextStatus = hadSuccess ? 'stale' : 'pending';
        runStatus = 'stale';
      }
    } else if (error instanceof IcsParseError) {
      errorCode = error.kind;
      // Corrupt / oversized / recurrence-bomb: never destructive. Keep events.
      nextStatus = hadSuccess ? 'stale' : 'invalid';
      runStatus = 'stale';
    }

    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.publicCalendar.updateMany({
        where: expectedDefinition(expected),
        data: { operationalStatus: nextStatus },
      });
      if (updated.count && runStatus === 'revoked')
        await tx.publicCalendarEvent.deleteMany({ where: { calendarId } });
    });
    await this.finishRun(runId, { status: runStatus, errorCode, errorMessage: this.redact(error) });
    this.logger.warn(
      `Public-calendar events sync for "${slug}" -> ${runStatus} (${errorCode}); data kept`,
    );
    return { slug, status: runStatus, received: 0, written: 0, removed: 0, errorCode };
  }

  // -------------------------------------------------------------------------

  private async finishRun(
    id: string,
    data: {
      status: string;
      feedBytes?: number;
      eventsReceived?: number;
      eventsExpanded?: number;
      recordsAccepted?: number;
      recordsRejected?: number;
      recordsWritten?: number;
      recordsRemoved?: number;
      errorCode?: string;
      errorMessage?: string;
    },
  ): Promise<void> {
    await this.prisma.publicCalendarSyncRun.update({
      where: { id },
      data: { ...data, finishedAt: new Date() },
    });
  }

  private redact(error: unknown): string {
    if (error instanceof Error) return `${error.name}`.slice(0, 120);
    return 'unknown error';
  }

  async lastSuccessfulCatalogAt(): Promise<Date | null> {
    const run = await this.prisma.publicCalendarSyncRun.findFirst({
      where: { kind: 'catalog', status: 'success', finishedAt: { not: null } },
      orderBy: { finishedAt: 'desc' },
      select: { finishedAt: true },
    });
    return run?.finishedAt ?? null;
  }
}
