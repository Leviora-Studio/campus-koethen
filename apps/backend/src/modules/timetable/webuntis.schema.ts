import { z } from 'zod';

/**
 * Schemas for the public WebUntis timetable view.
 *
 * This is an INTERNAL interface of a third party's web UI, not a published API.
 * It can change without notice, so nothing is trusted: every response is parsed
 * before a single row is written, and a shape change surfaces as a clean
 * validation failure that leaves stored data untouched.
 *
 * The observed contract is documented in
 * apps/backend/test/fixtures/webuntis/README.md and re-verified against the
 * live view on 2026-07-22.
 *
 * Two deliberate stances throughout:
 *  - unknown EXTRA fields are tolerated, because upstream adds them freely
 *  - unknown ENUM values are tolerated and normalised to `unknown` later,
 *    because a new status must never take the whole import down
 */

// --- /app/data ---------------------------------------------------------------

export const appDataSchema = z.object({
  currentSchoolYear: z.object({
    /** Dynamic. Never hardcoded — it changes every term. */
    id: z.number().int(),
    name: z.string(),
    dateRange: z.object({
      start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      end: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    }),
  }),
});

export type AppData = z.infer<typeof appDataSchema>;

// --- /timetable/filter?resourceType=CLASS ------------------------------------

const resourceRefSchema = z.object({
  id: z.number().int(),
  shortName: z.string(),
  longName: z.string().nullish(),
  displayName: z.string().nullish(),
});

export const filterResponseSchema = z.object({
  resourceType: z.string().nullish(),
  classes: z.array(
    z.object({
      class: resourceRefSchema,
      department: resourceRefSchema.nullish().transform((value) => value ?? null),
    }),
  ),
});

export type FilterResponse = z.infer<typeof filterResponseSchema>;

// --- /timetable/entries ------------------------------------------------------

/**
 * One item inside a `positionN` array. `removed` is populated for
 * substitutions, where it carries what used to be scheduled.
 */
const positionItemSchema = z.object({
  current: z
    .object({
      type: z.string().nullish(),
      status: z.string().nullish(),
      shortName: z.string().nullish(),
      longName: z.string().nullish(),
      displayName: z.string().nullish(),
    })
    .nullish(),
  removed: z
    .object({
      type: z.string().nullish(),
      shortName: z.string().nullish(),
      longName: z.string().nullish(),
      displayName: z.string().nullish(),
    })
    .nullish(),
});

const positionArray = z.array(positionItemSchema).nullish();

export const gridEntrySchema = z.object({
  /** Stable source key. Occasionally holds more than one id. */
  ids: z.array(z.number().int()).min(1),
  duration: z.object({
    /** Local wall clock, no zone. Interpreted as Europe/Berlin. */
    start: z.string().min(1),
    end: z.string().min(1),
  }),
  type: z.string().nullish(),
  status: z.string().nullish(),
  statusDetail: z.string().nullish(),
  name: z.string().nullish(),
  notesAll: z.string().nullish(),
  lessonText: z.string().nullish(),
  substitutionText: z.string().nullish(),
  position1: positionArray,
  position2: positionArray,
  position3: positionArray,
  position4: positionArray,
  position5: positionArray,
  position6: positionArray,
  position7: positionArray,
});

export const entriesResponseSchema = z.object({
  format: z.number().int().nullish(),
  days: z.array(
    z.object({
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      resourceType: z.string().nullish(),
      resource: resourceRefSchema,
      /** `NO_DATA` when the class has nothing that day. */
      status: z.string().nullish(),
      gridEntries: z.array(gridEntrySchema).default([]),
      dayEntries: z.array(z.unknown()).default([]),
    }),
  ),
  errors: z.array(z.unknown()).nullish(),
});

export type EntriesResponse = z.infer<typeof entriesResponseSchema>;
export type GridEntry = z.infer<typeof gridEntrySchema>;

// --- Position handling -------------------------------------------------------

export interface PositionRef {
  shortName: string;
  longName: string | null;
  displayName: string | null;
}

type PositionCarrier = Record<string, unknown>;

export interface AllPositions {
  subjects: PositionRef[];
  teachers: PositionRef[];
  rooms: PositionRef[];
  classes: PositionRef[];
  infos: PositionRef[];
}

/**
 * Single-pass position collector across ALL position slots for standard types.
 */
export function pickAllPositions(entry: PositionCarrier): AllPositions {
  const subjects: PositionRef[] = [];
  const teachers: PositionRef[] = [];
  const rooms: PositionRef[] = [];
  const classes: PositionRef[] = [];
  const infos: PositionRef[] = [];

  for (let slot = 1; slot <= 7; slot += 1) {
    const raw = entry[`position${slot}`];
    if (!Array.isArray(raw)) {
      continue;
    }
    for (const item of raw) {
      if (typeof item !== 'object' || item === null) {
        continue;
      }
      const current = (item as { current?: unknown }).current;
      if (typeof current !== 'object' || current === null) {
        continue;
      }
      const ref = current as Record<string, unknown>;
      const shortName = typeof ref['shortName'] === 'string' ? ref['shortName'] : '';
      if (!shortName) {
        continue;
      }
      const pos: PositionRef = {
        shortName,
        longName: typeof ref['longName'] === 'string' ? ref['longName'] : null,
        displayName: typeof ref['displayName'] === 'string' ? ref['displayName'] : null,
      };
      switch (ref['type']) {
        case 'SUBJECT':
          subjects.push(pos);
          break;
        case 'TEACHER':
          teachers.push(pos);
          break;
        case 'ROOM':
          rooms.push(pos);
          break;
        case 'CLASS':
          classes.push(pos);
          break;
        case 'INFO':
          infos.push(pos);
          break;
      }
    }
  }

  return { subjects, teachers, rooms, classes, infos };
}

/**
 * Collects every position entry of a given type, across ALL position slots.
 *
 * The slot index is meaningless upstream: ROOM was observed at positions 2 and
 * 3, CLASS at 3 and 4, SUBJECT at 1 and 2 — within a single recorded sample.
 * Reading `position3` as "the room" would therefore file rooms as classes for
 * a subset of entries, silently and plausibly.
 */
export function pickPositions(entry: PositionCarrier, type: string): PositionRef[] {
  const all = pickAllPositions(entry);
  switch (type) {
    case 'SUBJECT':
      return all.subjects;
    case 'TEACHER':
      return all.teachers;
    case 'ROOM':
      return all.rooms;
    case 'CLASS':
      return all.classes;
    case 'INFO':
      return all.infos;
    default: {
      const result: PositionRef[] = [];
      for (let slot = 1; slot <= 7; slot += 1) {
        const raw = entry[`position${slot}`];
        if (!Array.isArray(raw)) {
          continue;
        }
        for (const item of raw) {
          if (typeof item !== 'object' || item === null) {
            continue;
          }
          const current = (item as { current?: unknown }).current;
          if (typeof current !== 'object' || current === null) {
            continue;
          }
          const ref = current as Record<string, unknown>;
          if (ref['type'] !== type) {
            continue;
          }
          const shortName = typeof ref['shortName'] === 'string' ? ref['shortName'] : '';
          if (!shortName) {
            continue;
          }
          result.push({
            shortName,
            longName: typeof ref['longName'] === 'string' ? ref['longName'] : null,
            displayName: typeof ref['displayName'] === 'string' ? ref['displayName'] : null,
          });
        }
      }
      return result;
    }
  }
}

// --- Normalisation -----------------------------------------------------------

export type EntryStatus = 'regular' | 'changed' | 'cancelled' | 'unknown';
export type EntryType = 'regular_teaching' | 'additional' | 'unknown';

/**
 * `ADDITIONAL` maps to `regular`: from a student's point of view an extra
 * session still takes place. The distinction survives in `type`.
 */
const STATUS_MAP: Record<string, EntryStatus> = {
  REGULAR: 'regular',
  ADDITIONAL: 'regular',
  CHANGED: 'changed',
  CANCELLED: 'cancelled',
};

const TYPE_MAP: Record<string, EntryType> = {
  NORMAL_TEACHING_PERIOD: 'regular_teaching',
  ADDITIONAL_PERIOD: 'additional',
};

export function normalizeEntryStatus(raw: string | null | undefined): EntryStatus {
  if (!raw) {
    return 'unknown';
  }
  return STATUS_MAP[raw.toUpperCase()] ?? 'unknown';
}

export function normalizeEntryType(raw: string | null | undefined): EntryType {
  if (!raw) {
    return 'unknown';
  }
  return TYPE_MAP[raw.toUpperCase()] ?? 'unknown';
}

// --- Time --------------------------------------------------------------------

const SOURCE_TIMEZONE = 'Europe/Berlin';

const berlinOffsetFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: SOURCE_TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
});

/** Milliseconds Europe/Berlin is ahead of UTC at a given absolute instant. */
function berlinOffsetMs(instant: Date): number {
  const parts = berlinOffsetFormatter.formatToParts(instant);
  let year = 0;
  let month = 0;
  let day = 0;
  let hour = 0;
  let minute = 0;
  let second = 0;
  for (const part of parts) {
    switch (part.type) {
      case 'year':
        year = Number(part.value);
        break;
      case 'month':
        month = Number(part.value);
        break;
      case 'day':
        day = Number(part.value);
        break;
      case 'hour':
        hour = Number(part.value);
        break;
      case 'minute':
        minute = Number(part.value);
        break;
      case 'second':
        second = Number(part.value);
        break;
    }
  }

  const asUtc = Date.UTC(year, month - 1, day, hour, minute, second);
  return asUtc - instant.getTime();
}

/**
 * How many distinct wall clocks the memo below will hold.
 *
 * An entry-sync window is a few weeks of a fixed lesson grid, so the real
 * number of distinct values is in the hundreds. The bound exists because the
 * keys come from a third party's response: without it, every timestamp the
 * source has ever sent would be held for the lifetime of the worker process.
 */
export const MAX_WALL_CLOCK_CACHE_ENTRIES = 4_096;

/**
 * Wall clock -> epoch milliseconds.
 *
 * Milliseconds rather than `Date` on purpose: a memoised `Date` would be
 * mutable state shared between every caller that ever asked for the same wall
 * clock, so one `setTime()` would move all of them.
 */
const wallClockCache = new Map<string, number>();

/** How many wall clocks are memoised right now. Exposed so the bound is testable. */
export function wallClockCacheSize(): number {
  return wallClockCache.size;
}

/**
 * Converts a WebUntis local wall-clock string to an absolute instant.
 *
 * The source sends `2026-07-20T10:00` with no zone; it means Europe/Berlin.
 * Storing that as if it were UTC would shift every lesson by an hour in winter
 * and two in summer.
 *
 * Uses Intl rather than a date library: the zone database already ships with
 * Node, so this stays dependency-free and correct across DST changes. The
 * offset is resolved iteratively because the correct offset depends on the
 * instant we are still computing.
 *
 * That iteration costs two `Intl.DateTimeFormat.formatToParts()` calls, and
 * this is called twice per lesson (start and end) while an entry sync walks the
 * WHOLE catalogue — roughly 270 classes over four weeks. A lesson grid has only
 * a handful of distinct start and end times per day, so the same few hundred
 * wall clocks were being resolved tens of thousands of times. The answer is a
 * pure function of the string, so it is resolved once and remembered.
 */
export function toUtc(wallClock: string): Date {
  const memoised = wallClockCache.get(wallClock);
  if (memoised !== undefined) {
    return new Date(memoised);
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?/.exec(wallClock);
  if (!match) {
    // Deliberately before the memo is written: a value we refused to parse is
    // not an answer worth remembering.
    throw new Error(`Unparseable WebUntis timestamp: ${wallClock}`);
  }

  const [, year, month, day, hour, minute, second] = match;
  const naiveUtc = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second ?? '0'),
  );

  // First guess using the offset at the naive instant, then correct once. Two
  // passes settle every case including the DST boundaries; during the
  // spring-forward gap this lands on the following valid instant rather than
  // throwing, which is the sane behaviour for a timetable.
  let instant = new Date(naiveUtc - berlinOffsetMs(new Date(naiveUtc)));
  instant = new Date(naiveUtc - berlinOffsetMs(instant));

  // Oldest insertion goes first — the same bounded-map discipline the event-key
  // and ingredient-label memos in this codebase already use.
  if (wallClockCache.size >= MAX_WALL_CLOCK_CACHE_ENTRIES) {
    const oldest = wallClockCache.keys().next();
    if (!oldest.done) wallClockCache.delete(oldest.value);
  }
  wallClockCache.set(wallClock, instant.getTime());

  return instant;
}

export const TIMETABLE_TIMEZONE = SOURCE_TIMEZONE;
