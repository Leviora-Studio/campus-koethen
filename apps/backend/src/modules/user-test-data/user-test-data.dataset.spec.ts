import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { buildUserTestDataset, UserTestMapCatalog } from './user-test-data.dataset';

const catalog = JSON.parse(
  readFileSync(
    resolve(process.cwd(), '../../packages/campus-map/catalog/campus-map.catalog.json'),
    'utf8',
  ),
) as UserTestMapCatalog;

describe('buildUserTestDataset', () => {
  const input = {
    anchor: new Date('2026-08-06T12:00:00.000Z'),
    catalog,
    canteenSlugs: ['koethen-fasanerieallee', 'koethen-lohmannstrasse'],
  } as const;

  it('is deterministic and uses a reserved negative meal-id namespace', () => {
    const first = buildUserTestDataset(input);
    const second = buildUserTestDataset(input);

    expect(first).toEqual(second);
    expect(first.meals.length).toBeGreaterThan(50);
    expect(first.meals.every((meal) => meal.sourcePlanId < 0)).toBe(true);
    expect(new Set(first.meals.map((meal) => meal.sourcePlanId)).size).toBe(first.meals.length);
  });

  it('provides realistic menu facets, allergens, sprint meals and every price group', () => {
    const dataset = buildUserTestDataset(input);
    const codes = new Set(dataset.meals.flatMap((meal) => meal.ingredientCodes));

    expect(codes).toEqual(expect.objectContaining(new Set(['50', '51', '52', 'A1', 'C', 'F'])));
    expect(dataset.meals.some((meal) => meal.isSprint)).toBe(true);
    expect(
      dataset.meals.every((meal) =>
        ['student', 'employee', 'guest'].every((group) =>
          meal.prices.some((price) => price.group === group),
        ),
      ),
    ).toBe(true);
  });

  it('takes every timetable room from the current Ratke building catalogue', () => {
    const dataset = buildUserTestDataset(input);
    const allowedRooms = new Set(
      catalog.rooms
        .filter((room) => room.buildingKey === 'ratke-gebaeude')
        .map((room) => room.roomNumber),
    );
    const usedRooms = dataset.timetable.entries.flatMap((entry) =>
      entry.rooms.map((room) => room.shortName),
    );

    expect(dataset.timetable.entries.length).toBeGreaterThan(20);
    expect(usedRooms.every((room) => allowedRooms.has(room))).toBe(true);
    expect(usedRooms.some((room) => room.startsWith('1'))).toBe(true);
    expect(usedRooms.some((room) => room.startsWith('2'))).toBe(true);
  });

  it('does not put a demo or test marker on each visible record', () => {
    const dataset = buildUserTestDataset(input);
    const visibleLabels = [
      ...dataset.meals.flatMap((meal) => [meal.name, meal.subtitle ?? '']),
      dataset.timetable.group.shortName,
      dataset.timetable.group.longName,
      ...dataset.timetable.entries.flatMap((entry) => [entry.title, entry.note ?? '']),
    ];

    expect(visibleLabels.join(' ')).not.toMatch(/\b(?:demo|test)\b/i);
  });

  it('refuses a catalogue without suitable rooms', () => {
    expect(() =>
      buildUserTestDataset({
        ...input,
        catalog: { ...catalog, rooms: [] },
      }),
    ).toThrow(/room/i);
  });

  it('samples public calendars with the cases the calendar screens differ on', () => {
    const { calendars } = buildUserTestDataset(input);

    expect(calendars).toHaveLength(2);
    // Removal finds the synthetic ones by prefix; a slug without it would
    // survive `remove()` and pollute a real catalogue.
    expect(calendars.every((calendar) => calendar.slug.startsWith('user-test-'))).toBe(true);

    const events = calendars.flatMap((calendar) => calendar.events);
    expect(events.some((event) => event.allDay)).toBe(true);
    expect(events.some((event) => event.status === 'cancelled')).toBe(true);
    expect(events.some((event) => event.location === null)).toBe(true);

    // An all-day end is exclusive — the day after, at midnight.
    const allDay = events.find((event) => event.allDay)!;
    expect(allDay.endsAt.getTime() - allDay.startsAt.getTime()).toBe(24 * 60 * 60 * 1000);

    // Every occurrence key is unique per calendar, or the upsert would collide.
    for (const calendar of calendars) {
      const keys = calendar.events.map((event) => event.occurrenceKey);
      expect(new Set(keys).size).toBe(keys.length);
    }
  });

  it('names a real catalogue room as a location, and a bare number only in prose', () => {
    const { calendars } = buildUserTestDataset(input);
    const events = calendars.flatMap((calendar) => calendar.events);
    const roomNumbers = new Set(catalog.rooms.map((room) => room.roomNumber));

    // At least one location is a room the map can actually resolve, so the
    // room link in the detail sheet has something to point at.
    expect(events.some((event) => event.location !== null && roomNumbers.has(event.location))).toBe(
      true,
    );

    // And at least one description carries a bare number that must stay text.
    expect(events.some((event) => /\bRaum \d{3}\b/.test(event.description ?? ''))).toBe(true);
  });
});
