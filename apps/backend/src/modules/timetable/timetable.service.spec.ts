import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { TimetableService } from './timetable.service';

describe('TimetableService feature availability', () => {
  it('serves the seeded timetable when user-test data is enabled without WebUntis', () => {
    const service = new TimetableService(
      {} as PrismaService,
      {
        WEBUNTIS_ENABLED: false,
        USER_TEST_DATA_ENABLED: true,
      } as Env,
    );

    expect(service.featureEnabled).toBe(true);
  });
});

/**
 * Cost contract of the sync-run lookups behind /v1/timetable/status.
 *
 * Freshness and the covered window are two fields of the same run row, so
 * asking for them twice is one database roundtrip too many — and neither field
 * needs the counters or the error classification that a `select`-less
 * `findFirst` drags along. `lastSuccessful` is not exclusive to this endpoint
 * either: /v1/timetable/groups and /v1/timetable/week call it on every request
 * too, so the over-fetch was paid three times per page view.
 *
 * The response itself is covered end to end against a real PostgreSQL in
 * test/timetable-api.integration.spec.ts.
 */
describe('TimetableService status lookups', () => {
  const env = {
    WEBUNTIS_ENABLED: true,
    USER_TEST_DATA_ENABLED: false,
    WEBUNTIS_STALE_AFTER_MINUTES: 180,
  } as Env;

  const entryRun = {
    finishedAt: new Date('2026-08-24T02:00:00.000Z'),
    rangeFrom: new Date('2026-08-17T00:00:00.000Z'),
    rangeTo: new Date('2026-08-31T00:00:00.000Z'),
  };
  const groupRun = { finishedAt: new Date('2026-08-24T01:00:00.000Z') };

  function makePrisma() {
    return {
      timetableGroup: { count: jest.fn().mockResolvedValue(270) },
      timetableSyncRun: {
        findFirst: jest.fn(({ where }: { where: { kind: string } }) =>
          Promise.resolve(where.kind === 'entries' ? entryRun : groupRun),
        ),
      },
    };
  }

  it('answers with three queries and reads the entry run only once', async () => {
    const prisma = makePrisma();
    const service = new TimetableService(prisma as unknown as PrismaService, env);

    const status = await service.getStatus();

    expect(status.lastEntrySyncAt).toBe(entryRun.finishedAt.toISOString());
    expect(status.lastGroupSyncAt).toBe(groupRun.finishedAt.toISOString());
    expect(status.coveredFrom).toBe('2026-08-17');
    expect(status.coveredTo).toBe('2026-08-31');

    // One count plus one lookup per kind. The freshness of the entry run and
    // the window it confirmed come out of the same row.
    expect(prisma.timetableGroup.count).toHaveBeenCalledTimes(1);
    expect(prisma.timetableSyncRun.findFirst).toHaveBeenCalledTimes(2);
    const kinds = prisma.timetableSyncRun.findFirst.mock.calls.map(
      ([args]: [{ where: { kind: string } }]) => args.where.kind,
    );
    expect(kinds.sort()).toEqual(['entries', 'groups']);
  });

  it('selects only the columns the response actually reads', async () => {
    const prisma = makePrisma();
    const service = new TimetableService(prisma as unknown as PrismaService, env);

    await service.getStatus();

    const selects = new Map<string, unknown>(
      prisma.timetableSyncRun.findFirst.mock.calls.map(
        ([args]: [{ where: { kind: string }; select?: unknown }]) => [args.where.kind, args.select],
      ),
    );
    expect(selects.get('groups')).toEqual({ finishedAt: true });
    expect(selects.get('entries')).toEqual({
      finishedAt: true,
      rangeFrom: true,
      rangeTo: true,
    });
  });

  it('projects the freshness lookup on the other read paths too', async () => {
    const prisma = {
      timetableGroup: {
        count: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      timetableSyncRun: { findFirst: jest.fn().mockResolvedValue(groupRun) },
    };
    const service = new TimetableService(prisma as unknown as PrismaService, env);

    await service.listGroups({ requestedLocale: 'de', resolvedLocale: 'de' }, {});

    expect(prisma.timetableSyncRun.findFirst).toHaveBeenCalledTimes(1);
    expect(prisma.timetableSyncRun.findFirst.mock.calls[0]![0].select).toEqual({
      finishedAt: true,
    });
    expect(prisma.timetableGroup.findMany.mock.calls[0]![0].select).toEqual({
      id: true,
      shortName: true,
      longName: true,
      department: true,
    });
  });

  it('projects only public timetable fields for a week read', async () => {
    const timetableEntryGroup = { findMany: jest.fn().mockResolvedValue([]) };
    const prisma = {
      timetableGroup: {
        findFirst: jest.fn().mockResolvedValue({
          id: '43a7302c-19ce-4fd7-a06e-003599fd75d0',
          shortName: 'BAI23',
          longName: 'Angewandte Informatik 2023',
          department: '6',
        }),
      },
      timetableEntryGroup,
      timetableSyncRun: { findFirst: jest.fn().mockResolvedValue(entryRun) },
    };
    const service = new TimetableService(prisma as unknown as PrismaService, env);

    await service.getWeek(
      { requestedLocale: 'de', resolvedLocale: 'de' },
      '43a7302c-19ce-4fd7-a06e-003599fd75d0',
      { from: '2026-08-24', to: '2026-08-30' },
    );

    expect(prisma.timetableGroup.findFirst.mock.calls[0]![0].select).toEqual({
      id: true,
      shortName: true,
      longName: true,
      department: true,
    });
    expect(timetableEntryGroup.findMany.mock.calls[0]![0].select).toEqual({
      entry: {
        select: {
          id: true,
          date: true,
          startsAt: true,
          endsAt: true,
          title: true,
          subjectCode: true,
          type: true,
          status: true,
          teachers: true,
          rooms: true,
          note: true,
          groups: {
            select: {
              group: {
                select: { id: true, shortName: true, longName: true, department: true },
              },
            },
          },
        },
      },
    });
  });
});
