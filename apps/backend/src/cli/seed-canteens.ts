import { NestFactory } from '@nestjs/core';
import { JsonLogger } from '../common/logger/json-logger.service';
import { CanteenSyncService } from '../modules/canteen/canteen-sync.service';
import { WorkerModule } from '../worker.module';

/**
 * Idempotently creates or updates the canteen rows from canteens.config.ts.
 * Running it repeatedly produces no duplicates.
 */
async function main(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: new JsonLogger(),
  });

  const count = await app.get(CanteenSyncService).seedCanteens();
  process.stdout.write(`Seeded ${count} canteen(s).\n`);

  await app.close();
  process.exit(0);
}

void main();
