import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';

/**
 * Real-database helper for integration tests.
 *
 * The synchronisation guarantees this project makes ("an empty or failed
 * upstream response never deletes stored data") are statements about database
 * state. Asserting them against a mock would prove nothing, so these tests run
 * against a genuine PostgreSQL instance — locally via
 * infrastructure/local/compose.yaml, in CI via a postgres service container.
 */

export function requireDatabaseUrl(): string {
  const url = process.env['DATABASE_URL'];
  if (!url) {
    throw new Error(
      'DATABASE_URL is not set. Start the local stack with `pnpm compose:local:up` ' +
        'and copy apps/backend/.env.example to apps/backend/.env.',
    );
  }
  return url;
}

export function createTestPrisma(): PrismaClient {
  return new PrismaClient({ adapter: new PrismaPg({ connectionString: requireDatabaseUrl() }) });
}

/** Wipes all operational tables. Order respects foreign keys. */
export async function resetDatabase(prisma: PrismaClient): Promise<void> {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE meal_prices, meals, sync_runs, ingredient_definitions, canteens, ' +
      'public_calendar_events, public_calendar_sync_runs, public_calendars RESTART IDENTITY CASCADE',
  );
}
