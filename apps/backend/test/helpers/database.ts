import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';

/**
 * Real-database helper for integration tests.
 *
 * The synchronisation guarantees this project makes ("an empty or failed
 * upstream response never deletes stored data") are statements about database
 * state. Asserting them against a mock would prove nothing, so these tests run
 * against a genuine, isolated temporary PostgreSQL database — locally in a
 * disposable container, in CI via a postgres service container. Never point
 * these helpers at the development database from the local compose stack.
 */

export function requireDatabaseUrl(): string {
  const url = process.env['DATABASE_URL'];
  if (!url) {
    throw new Error('DATABASE_URL must explicitly point to an isolated temporary test database.');
  }
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error('Invalid test database URL');
  }
  const database = decodeURIComponent(parsed.pathname.slice(1));
  if (
    !['postgres:', 'postgresql:'].includes(parsed.protocol) ||
    !/^[A-Za-z0-9_]+$/.test(database) ||
    !/(^|_)test($|_)/i.test(database) ||
    parsed.searchParams.has('database') ||
    parsed.searchParams.has('dbname')
  ) {
    throw new Error(
      'Destructive integration tests require an explicitly named test database; development and production databases are refused.',
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
