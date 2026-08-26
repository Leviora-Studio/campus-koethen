import { toUtc } from '../timetable/webuntis.schema';

export interface UserTestMapRoom {
  roomNumber: string;
  buildingKey: string;
  floorKey: string;
  roomType: string;
  sortOrder: number;
}

export interface UserTestMapCatalog {
  rooms: UserTestMapRoom[];
}

export interface UserTestMealPrice {
  group: 'student' | 'employee' | 'guest';
  amount: string;
}

export interface UserTestMeal {
  sourcePlanId: number;
  canteenSlug: string;
  date: string;
  counterId: number;
  isSprint: boolean;
  name: string;
  subtitle: string | null;
  extras: string[];
  ingredientCodes: string[];
  prices: UserTestMealPrice[];
}

export interface UserTestCalendarEvent {
  occurrenceKey: string;
  uid: string;
  title: string;
  description: string | null;
  location: string | null;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  status: 'confirmed' | 'cancelled';
}

export interface UserTestCalendar {
  slug: string;
  nameDe: string;
  nameEn: string;
  colorHex: string;
  sortOrder: number;
  defaultSubscribed: boolean;
  includeEventDescription: boolean;
  includeEventLocation: boolean;
  events: UserTestCalendarEvent[];
}

export interface UserTestTimetableEntry {
  externalKey: string;
  date: string;
  startsAt: Date;
  endsAt: Date;
  title: string;
  subjectCode: string;
  type: 'regular_teaching' | 'additional';
  status: 'regular';
  teachers: never[];
  rooms: Array<{ shortName: string; longName: null }>;
  note: string | null;
}

export interface UserTestDataset {
  from: string;
  to: string;
  ingredientDefinitions: Array<{
    code: string;
    labelDe: string;
    kind: 'ingredient' | 'marker';
  }>;
  meals: UserTestMeal[];
  calendars: UserTestCalendar[];
  timetable: {
    context: {
      externalId: string;
      name: string;
      validFrom: string;
      validTo: string;
    };
    group: {
      externalId: string;
      shortName: string;
      longName: string;
      department: string;
    };
    entries: UserTestTimetableEntry[];
  };
}

interface BuildInput {
  anchor: Date;
  catalog: UserTestMapCatalog;
  canteenSlugs: readonly string[];
}

interface MealTemplate {
  name: string;
  subtitle: string | null;
  extras: string[];
  ingredientCodes: string[];
  isSprint: boolean;
  prices: UserTestMealPrice[];
}

interface LessonTemplate {
  start: string;
  end: string;
  title: string;
  subjectCode: string;
  type: 'regular_teaching' | 'additional';
  note: string | null;
}

const DAY_MS = 86_400_000;
const USER_TEST_MEAL_ID_BASE = 8_000_000;
const USER_TEST_BUILDING_KEY = 'ratke-gebaeude';
const USER_TEST_ROOM_TYPES = new Set(['room', 'lecture', 'seminar', 'lab', 'meeting']);

const INGREDIENT_DEFINITIONS: UserTestDataset['ingredientDefinitions'] = [
  { code: '50', labelDe: 'fleischlos', kind: 'marker' },
  { code: '51', labelDe: 'vegetarisch', kind: 'marker' },
  { code: '52', labelDe: 'vegan', kind: 'marker' },
  { code: '47', labelDe: 'Geflügel', kind: 'marker' },
  { code: 'A1', labelDe: 'enthält Weizengluten', kind: 'ingredient' },
  { code: 'C', labelDe: 'enthält Ei', kind: 'ingredient' },
  { code: 'E', labelDe: 'enthält Soja', kind: 'ingredient' },
  { code: 'F', labelDe: 'enthält Milch (einschließlich Laktose)', kind: 'ingredient' },
  { code: 'H', labelDe: 'enthält Sellerie', kind: 'ingredient' },
  { code: 'I', labelDe: 'enthält Senf', kind: 'ingredient' },
  { code: 'J', labelDe: 'enthält Sesam', kind: 'ingredient' },
];

const MEAL_TEMPLATES: readonly MealTemplate[] = [
  {
    name: 'Kartoffel-Gemüse-Pfanne',
    subtitle: 'mit Kräuterdip auf Sojabasis',
    extras: ['Salatbeilage'],
    ingredientCodes: ['52', 'A1', 'E', 'H'],
    isSprint: false,
    prices: prices('2.10', '3.40', '4.20'),
  },
  {
    name: 'Pasta mit Tomaten-Linsen-Sauce',
    subtitle: null,
    extras: ['Blattsalat'],
    ingredientCodes: ['50', '51', 'A1', 'C', 'F'],
    isSprint: false,
    prices: prices('2.35', '3.65', '4.45'),
  },
  {
    name: 'Hähnchengeschnetzeltes mit Reis',
    subtitle: 'dazu saisonales Gemüse',
    extras: [],
    ingredientCodes: ['47', 'F', 'I'],
    isSprint: false,
    prices: prices('2.85', '4.15', '4.95'),
  },
  {
    name: 'Couscous-Bowl mit Ofengemüse',
    subtitle: 'mit Sesam-Dressing',
    extras: ['Tagesdessert'],
    ingredientCodes: ['51', 'A1', 'J'],
    isSprint: true,
    prices: prices('2.55', '3.85', '4.65'),
  },
];

const LESSONS_BY_WEEKDAY: Readonly<Record<number, readonly LessonTemplate[]>> = {
  1: [
    lesson('08:00', '09:30', 'Grundlagen der Informatik', 'GIN', 'regular_teaching'),
    lesson('10:00', '11:30', 'Mathematik', 'MAT', 'regular_teaching'),
  ],
  2: [
    lesson('09:45', '11:15', 'Programmierung', 'PROG', 'regular_teaching'),
    lesson('13:00', '14:30', 'Datenbanken', 'DB', 'regular_teaching'),
  ],
  3: [
    lesson('08:00', '09:30', 'Technisches Englisch', 'TEN', 'regular_teaching'),
    lesson('11:30', '13:00', 'Softwareentwicklung', 'SWE', 'regular_teaching'),
  ],
  4: [
    lesson('10:00', '11:30', 'Rechnernetze', 'RN', 'regular_teaching'),
    lesson('14:00', '15:30', 'Mediengestaltung', 'MG', 'regular_teaching'),
  ],
  5: [
    lesson('09:00', '12:15', 'Projektwerkstatt', 'PROJ', 'additional', 'Gemeinsame Arbeitsphase'),
  ],
};

function prices(student: string, employee: string, guest: string): UserTestMealPrice[] {
  return [
    { group: 'student', amount: student },
    { group: 'employee', amount: employee },
    { group: 'guest', amount: guest },
  ];
}

function lesson(
  start: string,
  end: string,
  title: string,
  subjectCode: string,
  type: LessonTemplate['type'],
  note: string | null = null,
): LessonTemplate {
  return { start, end, title, subjectCode, type, note };
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function addDays(date: Date, amount: number): Date {
  return new Date(date.getTime() + amount * DAY_MS);
}

function utcDate(date: Date): Date {
  return new Date(`${isoDate(date)}T12:00:00.000Z`);
}

function mondayOf(date: Date): Date {
  const normalized = utcDate(date);
  const weekday = normalized.getUTCDay();
  return addDays(normalized, weekday === 0 ? -6 : 1 - weekday);
}

/**
 * Builds the complete synthetic dataset without touching a database.
 *
 * Visible records intentionally look like ordinary campus content. The API's
 * environment endpoint and the global app banner carry the mandatory test-data
 * disclosure once for the whole deployment instead of repeating it per card.
 */
/// Two public calendars' worth of events across the seeded window.
///
/// Deliberately varied, because the calendar screens differ by case and a
/// uniform feed would leave most of them untested: timed and all-day entries,
/// one cancellation, a room named exactly as the map spells it, and prose
/// locations that must NOT become a room link.
function buildCalendars(weekStart: Date, roomNumber: string): UserTestCalendar[] {
  const events: UserTestCalendarEvent[] = [];
  const at = (day: number, time: string): Date =>
    toUtc(`${isoDate(addDays(weekStart, day))}T${time}:00`);

  const timed = (
    day: number,
    start: string,
    end: string,
    title: string,
    location: string | null,
    description: string | null,
    status: 'confirmed' | 'cancelled' = 'confirmed',
  ): void => {
    events.push({
      occurrenceKey: `campus-${day}-${start.replace(':', '')}`,
      uid: `campus-${day}-${start.replace(':', '')}@user-test.invalid`,
      title,
      description,
      location,
      startsAt: at(day, start),
      endsAt: at(day, end),
      allDay: false,
      status,
    });
  };

  timed(
    1,
    '18:00',
    '20:00',
    'Semester-Auftakt (Testdaten)',
    roomNumber,
    `Offen für alle. Treffpunkt ist ${roomNumber}.`,
  );
  timed(
    3,
    '16:00',
    '17:30',
    'Lernraum-Sprechstunde (Testdaten)',
    'Innenhof',
    'Ohne Anmeldung, bei Regen im Foyer.',
  );
  timed(
    8,
    '19:00',
    '22:00',
    'Filmabend (Testdaten)',
    'Mensa Fasanerieallee',
    'Beginn 19 Uhr, Einlass ab 18:30.',
  );
  timed(
    10,
    '09:00',
    '10:00',
    'Führung für Erstsemester (Testdaten)',
    'Haupteingang',
    'Dauer etwa 60 Minuten.',
    'cancelled',
  );
  timed(15, '14:00', '16:00', 'Repair-Café (Testdaten)', roomNumber, 'Werkzeug ist vorhanden.');

  // All-day entries live in their own band in the week view.
  for (const [index, day] of [4, 17].entries()) {
    events.push({
      occurrenceKey: `campus-allday-${day}`,
      uid: `campus-allday-${day}@user-test.invalid`,
      title: index === 0 ? 'Projektwoche (Testdaten)' : 'Rückmeldefrist (Testdaten)',
      description:
        index === 0
          ? 'Ganztägig, keine regulären Lehrveranstaltungen.'
          : 'Letzter Tag der Rückmeldung.',
      location: null,
      startsAt: toUtc(`${isoDate(addDays(weekStart, day))}T00:00:00`),
      // All-day ends are EXCLUSIVE.
      endsAt: toUtc(`${isoDate(addDays(weekStart, day + 1))}T00:00:00`),
      allDay: true,
      status: 'confirmed',
    });
  }

  const sturaEvents: UserTestCalendarEvent[] = [
    {
      occurrenceKey: 'stura-sitzung-1',
      uid: 'stura-sitzung-1@user-test.invalid',
      title: 'Sitzung des Studierendenrats (Testdaten)',
      description: 'Öffentlich. Die Tagesordnung hängt aus.',
      location: roomNumber,
      startsAt: at(2, '18:30'),
      endsAt: at(2, '21:00'),
      allDay: false,
      status: 'confirmed',
    },
    {
      occurrenceKey: 'stura-sitzung-2',
      uid: 'stura-sitzung-2@user-test.invalid',
      title: 'Sitzung des Studierendenrats (Testdaten)',
      description: 'Öffentlich. Die Tagesordnung hängt aus.',
      location: roomNumber,
      startsAt: at(16, '18:30'),
      endsAt: at(16, '21:00'),
      allDay: false,
      status: 'confirmed',
    },
    {
      occurrenceKey: 'stura-sprechstunde',
      uid: 'stura-sprechstunde@user-test.invalid',
      title: 'Offene Sprechstunde (Testdaten)',
      // A bare number in prose: must stay text, never a room link.
      description: 'Wir sind ab 14 Uhr da, Raum 202 ist an dem Tag belegt.',
      location: 'Büro im Erdgeschoss',
      startsAt: at(9, '14:00'),
      endsAt: at(9, '16:00'),
      allDay: false,
      status: 'confirmed',
    },
  ];

  return [
    {
      slug: 'user-test-campus-events',
      nameDe: 'Campus-Veranstaltungen (Testdaten)',
      nameEn: 'Campus events (test data)',
      colorHex: '#2E7D8F',
      sortOrder: 10,
      defaultSubscribed: true,
      includeEventDescription: true,
      includeEventLocation: true,
      events,
    },
    {
      slug: 'user-test-stura',
      nameDe: 'Studierendenrat (Testdaten)',
      nameEn: 'Student body (test data)',
      colorHex: '#C98A2B',
      sortOrder: 20,
      defaultSubscribed: true,
      includeEventDescription: true,
      includeEventLocation: true,
      events: sturaEvents,
    },
  ];
}

export function buildUserTestDataset(input: BuildInput): UserTestDataset {
  const anchor = utcDate(input.anchor);
  const weekStart = mondayOf(anchor);
  const rooms = input.catalog.rooms
    .filter(
      (room) =>
        room.buildingKey === USER_TEST_BUILDING_KEY && USER_TEST_ROOM_TYPES.has(room.roomType),
    )
    .sort((left, right) => left.sortOrder - right.sortOrder);

  if (rooms.length === 0) {
    throw new Error('The canonical map catalogue contains no suitable user-test rooms.');
  }
  if (input.canteenSlugs.length === 0) {
    throw new Error('At least one canteen is required for user-test data.');
  }

  const meals: UserTestMeal[] = [];
  for (const [canteenIndex, canteenSlug] of input.canteenSlugs.entries()) {
    for (let dayOffset = 0; dayOffset < 21; dayOffset += 1) {
      const date = addDays(anchor, dayOffset);
      const weekday = date.getUTCDay();
      if (weekday === 0 || weekday === 6) continue;

      for (const [mealIndex, template] of MEAL_TEMPLATES.entries()) {
        meals.push({
          sourcePlanId: -(
            USER_TEST_MEAL_ID_BASE +
            canteenIndex * 100_000 +
            dayOffset * 100 +
            mealIndex
          ),
          canteenSlug,
          date: isoDate(date),
          counterId: mealIndex + 1,
          isSprint: template.isSprint,
          name: template.name,
          subtitle: template.subtitle,
          extras: [...template.extras],
          ingredientCodes: [...template.ingredientCodes],
          prices: template.prices.map((price) => ({ ...price })),
        });
      }
    }
  }

  const entries: UserTestTimetableEntry[] = [];
  let roomIndex = 0;
  for (let dayOffset = 0; dayOffset < 28; dayOffset += 1) {
    const date = addDays(weekStart, dayOffset);
    const templates = LESSONS_BY_WEEKDAY[date.getUTCDay()] ?? [];
    for (const [slotIndex, template] of templates.entries()) {
      const room = rooms[roomIndex % rooms.length]!;
      roomIndex += 1;
      const dateText = isoDate(date);
      entries.push({
        externalKey: `week-${Math.floor(dayOffset / 7)}-day-${date.getUTCDay()}-slot-${slotIndex}`,
        date: dateText,
        startsAt: toUtc(`${dateText}T${template.start}:00`),
        endsAt: toUtc(`${dateText}T${template.end}:00`),
        title: template.title,
        subjectCode: template.subjectCode,
        type: template.type,
        status: 'regular',
        teachers: [],
        rooms: [{ shortName: room.roomNumber, longName: null }],
        note: template.note,
      });
    }
  }

  const validTo = isoDate(addDays(weekStart, 27));
  return {
    from: isoDate(anchor),
    to: validTo,
    ingredientDefinitions: INGREDIENT_DEFINITIONS.map((definition) => ({ ...definition })),
    meals,
    calendars: buildCalendars(weekStart, rooms[0]!.roomNumber),
    timetable: {
      context: {
        externalId: 'current-user-test-period',
        name: 'Aktueller Zeitraum',
        validFrom: isoDate(weekStart),
        validTo,
      },
      group: {
        externalId: 'inf-a',
        shortName: 'INF A',
        longName: 'Informatik · Studiengruppe A',
        department: 'Informatik',
      },
      entries,
    },
  };
}
