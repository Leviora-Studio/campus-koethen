import { Env } from '../../config/env.schema';
import { TimetableController } from './timetable.controller';
import { TimetableService } from './timetable.service';

describe('TimetableController groups metadata', () => {
  afterEach(() => jest.useRealTimers());

  it('advertises the configured timetable horizon to the app', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-09-24T12:00:00.000Z'));
    const service = {
      listGroups: jest.fn().mockResolvedValue({ data: [], lastSyncAt: null, stale: false }),
      featureEnabled: true,
    } as unknown as TimetableService;
    const controller = new TimetableController(service, {
      WEBUNTIS_LOOKAHEAD_DAYS: 28,
    } as Env);

    const response = await controller.groups({ requestedLocale: 'de', resolvedLocale: 'de' }, {});

    expect(response.meta.from).toBe('2026-09-24');
    expect(response.meta.to).toBe('2026-10-22');
  });

  it('advertises a full semester when configured for 210 days', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-09-24T12:00:00.000Z'));
    const service = {
      listGroups: jest.fn().mockResolvedValue({ data: [], lastSyncAt: null, stale: false }),
      featureEnabled: true,
    } as unknown as TimetableService;
    const controller = new TimetableController(service, {
      WEBUNTIS_LOOKAHEAD_DAYS: 210,
    } as Env);

    const response = await controller.groups({ requestedLocale: 'de', resolvedLocale: 'de' }, {});

    expect(response.meta.to).toBe('2027-04-22');
  });
});
