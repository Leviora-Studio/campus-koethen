import { NestFactory } from '@nestjs/core';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { JsonLogger } from '../common/logger/json-logger.service';
import { CanteenSyncService } from '../modules/canteen/canteen-sync.service';
import { MeineMensaClient } from '../modules/canteen/meine-mensa.client';
import { foodPlanResponseSchema } from '../modules/canteen/meine-mensa.schema';
import { WorkerModule } from '../worker.module';

/**
 * Administrative one-off synchronisation.
 *
 * Exposed as a CLI on purpose: there is NO public, unauthenticated sync
 * endpoint, because that would let anyone drive load onto a third-party source.
 *
 *   pnpm --filter @campus/backend sync:canteens
 *   pnpm --filter @campus/backend sync:canteens -- --fixture
 *
 * `--fixture` runs the whole pipeline against the stored fixtures instead of
 * the live source — useful for local work without touching the upstream.
 */
async function main(): Promise<void> {
  const useFixture = process.argv.includes('--fixture');

  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: new JsonLogger(),
  });

  if (useFixture) {
    const client = app.get(MeineMensaClient);
    // Replace only the network call; validation and persistence stay real.
    const byLocation: Record<number, string> = {
      7: 'success.json',
      22: 'lohmannstrasse.json',
    };
    // Reads synchronously but returns a promise, matching the real method's
    // signature without pretending there is anything to await.
    (client as unknown as Record<string, unknown>)['fetchFoodPlans'] = (request: {
      locationId: number;
    }) => {
      const file = byLocation[request.locationId] ?? 'empty.json';
      const raw = JSON.parse(
        readFileSync(join(__dirname, '../../test/fixtures/meine-mensa', file), 'utf8'),
      ) as unknown;
      return Promise.resolve(foodPlanResponseSchema.parse(raw));
    };
  }

  const sync = app.get(CanteenSyncService);
  const outcomes = await sync.syncAll();

  for (const outcome of outcomes) {
    process.stdout.write(
      `${outcome.canteenSlug}: ${outcome.status} ` +
        `(received=${outcome.recordsReceived} upserted=${outcome.recordsUpserted} ` +
        `rejected=${outcome.recordsRejected} withdrawn=${outcome.recordsRemoved})` +
        `${outcome.errorMessage ? ` error=${outcome.errorMessage}` : ''}\n`,
    );
  }

  await app.close();

  // A failed run must be visible to the shell that invoked it.
  process.exit(outcomes.some((outcome) => outcome.status === 'failed') ? 1 : 0);
}

void main();
