import { NestFactory } from '@nestjs/core';
import {
  UserTestDataSeedService,
  UserTestRemovalSummary,
  UserTestSeedSummary,
} from '../modules/user-test-data/user-test-data.seed.service';
import { WorkerModule } from '../worker.module';

export type UserTestSeedMode = 'seed' | 'dry-run' | 'remove';

export function parseUserTestSeedMode(args: readonly string[]): UserTestSeedMode {
  if (args.length === 0) return 'seed';
  if (args.length === 1 && args[0] === '--dry-run') return 'dry-run';
  if (args.length === 1 && args[0] === '--remove') return 'remove';
  throw new Error('Usage: seed-user-test-data [--dry-run | --remove]');
}

async function main(): Promise<void> {
  const mode = parseUserTestSeedMode(process.argv.slice(2));
  const app = await NestFactory.createApplicationContext(WorkerModule);
  try {
    const service = app.get(UserTestDataSeedService);
    const result: UserTestSeedSummary | UserTestRemovalSummary =
      mode === 'dry-run'
        ? service.preview()
        : mode === 'remove'
          ? await service.remove()
          : await service.seed();
    process.stdout.write(`${JSON.stringify({ operation: mode, ...result })}\n`);
  } finally {
    await app.close();
  }
}

if (require.main === module) {
  void main().catch((error: unknown) => {
    // The command can run against a real database; an unhandled driver error
    // must not echo a connection string or row contents to an operator log.
    void error;
    process.stderr.write('User-test data command failed; inspect the backend logs.\n');
    process.exitCode = 1;
  });
}
