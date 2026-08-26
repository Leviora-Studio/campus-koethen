import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { USER_TEST_SOURCE } from './user-test-data.constants';

@Injectable()
export class UserTestEnvironmentService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * The row check prevents a deployment from hiding its disclosure merely by
   * flipping the switch before the synthetic rows have been removed.
   */
  async isActive(): Promise<boolean> {
    if (this.env.USER_TEST_DATA_ENABLED) return true;

    const [meals, timetableEntries] = await Promise.all([
      this.prisma.meal.count({ where: { source: USER_TEST_SOURCE } }),
      this.prisma.timetableEntry.count({ where: { source: USER_TEST_SOURCE } }),
    ]);
    return meals > 0 || timetableEntries > 0;
  }
}
