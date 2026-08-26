import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  appDataSchema,
  entriesResponseSchema,
  filterResponseSchema,
  normalizeEntryStatus,
  normalizeEntryType,
  pickPositions,
  MAX_WALL_CLOCK_CACHE_ENTRIES,
  toUtc,
  wallClockCacheSize,
} from './webuntis.schema';

const fixture = (name: string): unknown =>
  JSON.parse(readFileSync(join(__dirname, '../../../test/fixtures/webuntis', name), 'utf8'));

describe('WebUntis schemas', () => {
  describe('appDataSchema', () => {
    it('accepts the recorded response and exposes the school year context', () => {
      const parsed = appDataSchema.parse(fixture('app-data.json'));
      expect(parsed.currentSchoolYear.id).toBe(49);
      expect(parsed.currentSchoolYear.name).toBe('2026/2026');
      expect(parsed.currentSchoolYear.dateRange.start).toBe('2026-04-07');
      expect(parsed.currentSchoolYear.dateRange.end).toBe('2026-09-30');
    });

    it('tolerates unknown extra fields, because upstream adds them without notice', () => {
      const raw = fixture('app-data.json') as Record<string, unknown>;
      const result = appDataSchema.safeParse({ ...raw, somethingBrandNew: { a: 1 } });
      expect(result.success).toBe(true);
    });

    it('rejects a response without a school year id', () => {
      const raw = fixture('app-data.json') as { currentSchoolYear: Record<string, unknown> };
      const broken = { ...raw, currentSchoolYear: { ...raw.currentSchoolYear, id: undefined } };
      expect(appDataSchema.safeParse(broken).success).toBe(false);
    });
  });

  describe('filterResponseSchema', () => {
    it('accepts the recorded class catalogue', () => {
      const parsed = filterResponseSchema.parse(fixture('filter-classes.json'));
      expect(parsed.classes.length).toBeGreaterThan(0);
      const first = parsed.classes[0]!;
      expect(typeof first.class.id).toBe('number');
      expect(first.class.shortName.length).toBeGreaterThan(0);
    });

    it('keeps the department when present and tolerates its absence', () => {
      const parsed = filterResponseSchema.parse({
        resourceType: 'CLASS',
        classes: [
          { class: { id: 1, shortName: 'A', longName: 'Alpha' }, department: null },
          {
            class: { id: 2, shortName: 'B', longName: 'Beta' },
            department: { id: 9, shortName: 'FB5', longName: 'FB5' },
          },
        ],
      });
      expect(parsed.classes[0]!.department).toBeNull();
      expect(parsed.classes[1]!.department?.shortName).toBe('FB5');
    });

    it('rejects a class without an id', () => {
      const result = filterResponseSchema.safeParse({
        resourceType: 'CLASS',
        classes: [{ class: { shortName: 'A', longName: 'Alpha' } }],
      });
      expect(result.success).toBe(false);
    });
  });

  describe('entriesResponseSchema', () => {
    it('accepts the recorded week', () => {
      const parsed = entriesResponseSchema.parse(fixture('entries-week.json'));
      expect(parsed.days.length).toBeGreaterThan(0);
      expect(parsed.days.some((d) => d.gridEntries.length > 0)).toBe(true);
    });

    it('accepts a structurally valid empty week', () => {
      // An empty week is a legitimate answer (semester break), NOT an error.
      // Deciding what to do with it is the sync service's job, not the parser's.
      const parsed = entriesResponseSchema.parse(fixture('entries-empty.json'));
      expect(parsed.days.every((d) => d.gridEntries.length === 0)).toBe(true);
    });

    it('rejects malformed JSON payloads at the schema level', () => {
      expect(entriesResponseSchema.safeParse({ format: 2 }).success).toBe(false);
      expect(entriesResponseSchema.safeParse({ days: 'nope' }).success).toBe(false);
    });

    it('tolerates unknown position types and unknown statuses', () => {
      const result = entriesResponseSchema.safeParse({
        format: 2,
        days: [
          {
            date: '2026-07-20',
            resourceType: 'CLASS',
            resource: { id: 1, shortName: 'A', longName: 'Alpha' },
            status: 'SOMETHING_NEW',
            dayEntries: [],
            gridEntries: [
              {
                ids: [1],
                duration: { start: '2026-07-20T10:00', end: '2026-07-20T11:30' },
                type: 'BRAND_NEW_TYPE',
                status: 'BRAND_NEW_STATUS',
                position1: [
                  {
                    current: { type: 'MYSTERY', status: 'REGULAR', shortName: 'x' },
                    removed: null,
                  },
                ],
              },
            ],
            backEntries: [],
          },
        ],
      });
      expect(result.success).toBe(true);
    });

    it('rejects an entry without a duration', () => {
      const result = entriesResponseSchema.safeParse({
        format: 2,
        days: [
          {
            date: '2026-07-20',
            resource: { id: 1, shortName: 'A', longName: 'A' },
            gridEntries: [{ ids: [1], type: 'X', status: 'Y' }],
          },
        ],
      });
      expect(result.success).toBe(false);
    });
  });

  describe('pickPositions', () => {
    // The whole point: position INDEX is meaningless upstream. ROOM was
    // observed at positions 2 and 3, CLASS at 3 and 4. Selecting by index
    // would silently file rooms as classes.
    const entry = {
      position1: [{ current: { type: 'ROOM', shortName: 'R1', longName: 'Room One' } }],
      position2: [{ current: { type: 'TEACHER', shortName: 'T1', displayName: 'Demo One' } }],
      position4: [
        { current: { type: 'ROOM', shortName: 'R2', longName: 'Room Two' } },
        { current: { type: 'CLASS', shortName: 'C1', longName: 'Class One' } },
      ],
    };

    it('collects a type from every position, regardless of index', () => {
      const rooms = pickPositions(entry, 'ROOM');
      expect(rooms.map((r) => r.shortName).sort()).toEqual(['R1', 'R2']);
    });

    it('returns an empty list for a type that is absent', () => {
      expect(pickPositions(entry, 'SUBJECT')).toEqual([]);
    });

    it('ignores null positions without throwing', () => {
      expect(pickPositions({ position3: null, position7: undefined }, 'ROOM')).toEqual([]);
    });
  });

  describe('status and type normalisation', () => {
    it('maps the observed vocabulary', () => {
      expect(normalizeEntryStatus('REGULAR')).toBe('regular');
      expect(normalizeEntryStatus('CHANGED')).toBe('changed');
      expect(normalizeEntryStatus('CANCELLED')).toBe('cancelled');
      expect(normalizeEntryStatus('ADDITIONAL')).toBe('regular');
      expect(normalizeEntryType('NORMAL_TEACHING_PERIOD')).toBe('regular_teaching');
      expect(normalizeEntryType('ADDITIONAL_PERIOD')).toBe('additional');
    });

    it('maps anything unrecognised to unknown instead of throwing', () => {
      expect(normalizeEntryStatus('SOMETHING_ELSE')).toBe('unknown');
      expect(normalizeEntryStatus(null)).toBe('unknown');
      expect(normalizeEntryType('FUTURE_PERIOD_KIND')).toBe('unknown');
      expect(normalizeEntryType(undefined)).toBe('unknown');
    });

    it('is case-insensitive, so a casing change upstream does not blank the data', () => {
      expect(normalizeEntryStatus('cancelled')).toBe('cancelled');
    });
  });

  describe('toUtc — Europe/Berlin wall clock to absolute time', () => {
    it('converts winter time (CET, UTC+1)', () => {
      expect(toUtc('2026-01-15T10:00').toISOString()).toBe('2026-01-15T09:00:00.000Z');
    });

    it('converts summer time (CEST, UTC+2)', () => {
      expect(toUtc('2026-07-20T10:00').toISOString()).toBe('2026-07-20T08:00:00.000Z');
    });

    it('handles the spring-forward boundary', () => {
      // 2026-03-29: 02:00 CET jumps to 03:00 CEST.
      expect(toUtc('2026-03-29T01:30').toISOString()).toBe('2026-03-29T00:30:00.000Z');
      expect(toUtc('2026-03-29T03:30').toISOString()).toBe('2026-03-29T01:30:00.000Z');
    });

    it('handles the autumn-back boundary', () => {
      // 2026-10-25: 03:00 CEST falls back to 02:00 CET.
      expect(toUtc('2026-10-25T01:30').toISOString()).toBe('2026-10-24T23:30:00.000Z');
      expect(toUtc('2026-10-25T04:30').toISOString()).toBe('2026-10-25T03:30:00.000Z');
    });

    it('accepts seconds when upstream supplies them', () => {
      expect(toUtc('2026-07-20T10:00:30').toISOString()).toBe('2026-07-20T08:00:30.000Z');
    });

    it('throws on an unparseable value rather than inventing a time', () => {
      expect(() => toUtc('not-a-time')).toThrow();
    });

    it('repeats an answer it has already given, across a DST boundary', () => {
      // The conversion is memoised. Asking twice must not be able to drift, and
      // must not depend on which wall clocks were asked for in between.
      const first = toUtc('2026-03-29T03:30');
      toUtc('2026-01-15T10:00');
      toUtc('2026-07-20T10:00');
      const again = toUtc('2026-03-29T03:30');

      expect(again.toISOString()).toBe(first.toISOString());
      expect(again.toISOString()).toBe('2026-03-29T01:30:00.000Z');
    });

    it('hands every caller its own Date rather than a shared instance', () => {
      // A memoised Date object would be mutable shared state: one caller
      // calling setTime() would move every lesson that was ever converted from
      // the same wall clock.
      const first = toUtc('2026-05-04T08:00');
      const second = toUtc('2026-05-04T08:00');

      expect(second).not.toBe(first);
      expect(second.getTime()).toBe(first.getTime());

      first.setTime(0);
      expect(toUtc('2026-05-04T08:00').toISOString()).toBe('2026-05-04T06:00:00.000Z');
    });

    it('does not cache a value it refused to parse', () => {
      expect(() => toUtc('not-a-time')).toThrow();
      expect(() => toUtc('not-a-time')).toThrow();
    });

    it('keeps the memo bounded instead of growing with every distinct value', () => {
      // Every wall clock the source has ever sent would otherwise be held for
      // the lifetime of the worker process.
      for (let minute = 0; minute < MAX_WALL_CLOCK_CACHE_ENTRIES + 50; minute += 1) {
        const day = String((minute % 28) + 1).padStart(2, '0');
        const hh = String(Math.floor(minute / 60) % 24).padStart(2, '0');
        const mm = String(minute % 60).padStart(2, '0');
        toUtc(`2027-06-${day}T${hh}:${mm}:${String(minute % 60).padStart(2, '0')}`);
      }

      expect(wallClockCacheSize()).toBeLessThanOrEqual(MAX_WALL_CLOCK_CACHE_ENTRIES);
      // Still correct after eviction.
      expect(toUtc('2026-01-15T10:00').toISOString()).toBe('2026-01-15T09:00:00.000Z');
    });
  });
});
