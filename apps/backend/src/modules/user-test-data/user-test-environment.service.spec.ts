import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { UserTestEnvironmentService } from './user-test-environment.service';

describe('UserTestEnvironmentService', () => {
  function makeService(options: { enabled: boolean; meals?: number; timetableEntries?: number }): {
    service: UserTestEnvironmentService;
    prisma: { meal: { count: jest.Mock }; timetableEntry: { count: jest.Mock } };
  } {
    const prisma = {
      meal: { count: jest.fn().mockResolvedValue(options.meals ?? 0) },
      timetableEntry: {
        count: jest.fn().mockResolvedValue(options.timetableEntries ?? 0),
      },
    };
    const env = { USER_TEST_DATA_ENABLED: options.enabled } as Env;
    return {
      service: new UserTestEnvironmentService(prisma as unknown as PrismaService, env),
      prisma,
    };
  }

  it('is active whenever the deployment explicitly enables user-test data', async () => {
    const { service, prisma } = makeService({ enabled: true });

    await expect(service.isActive()).resolves.toBe(true);
    expect(prisma.meal.count).not.toHaveBeenCalled();
  });

  it('stays active while seeded rows remain even if the switch was turned off too early', async () => {
    const { service } = makeService({ enabled: false, meals: 1 });
    await expect(service.isActive()).resolves.toBe(true);
  });

  it('is inactive only when both the switch and all seeded rows are absent', async () => {
    const { service } = makeService({ enabled: false });
    await expect(service.isActive()).resolves.toBe(false);
  });
});
