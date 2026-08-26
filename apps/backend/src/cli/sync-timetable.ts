import { NestFactory } from '@nestjs/core';
import { JsonLogger } from '../common/logger/json-logger.service';
import { TimetableSyncService } from '../modules/timetable/timetable-sync.service';
import { WorkerModule } from '../worker.module';

/**
 * Administrative one-off timetable synchronisation.
 *
 * Exposed as a CLI on purpose: there is NO public, unauthenticated sync
 * endpoint, because that would let anyone drive load onto a third-party source.
 *
 *   pnpm --filter @campus/backend sync:timetable
 *
 * Runs the same three steps the worker runs — context, catalogue, entries —
 * once, in order, and stops if the context cannot be resolved. Honours
 * WEBUNTIS_ENABLED: with the flag off it reports `disabled` and touches
 * nothing, exactly like the scheduled job.
 */
async function main(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: new JsonLogger(),
  });

  const sync = app.get(TimetableSyncService);
  const outcomes: Array<{ kind: string; status: string; line: string }> = [];

  const context = await sync.syncContext();
  outcomes.push({
    kind: 'context',
    status: context.status,
    line: `context: ${context.status}`,
  });

  if (context.status === 'success') {
    const groups = await sync.syncGroups();
    outcomes.push({
      kind: 'groups',
      status: groups.status,
      line:
        `groups: ${groups.status} ` +
        `(received=${groups.received} written=${groups.written} ` +
        `retired=${groups.removed} rejected=${groups.rejected})`,
    });

    const window = sync.windowFor();
    const entries = await sync.syncEntries(window.from, window.to);
    outcomes.push({
      kind: 'entries',
      status: entries.status,
      line:
        `entries ${window.from}..${window.to}: ${entries.status} ` +
        `(received=${entries.received} written=${entries.written} ` +
        `rejected=${entries.rejected} withdrawn=${entries.removed})`,
    });
  } else {
    // No school year id means no catalogue and no entries can be fetched.
    process.stdout.write('context failed; skipping catalogue and entries\n');
  }

  for (const outcome of outcomes) {
    process.stdout.write(`${outcome.line}\n`);
  }

  await app.close();

  // A failed step must be visible to the shell that invoked it. `disabled` is
  // not a failure — it is the honest state when the feature is off.
  const failed = outcomes.some((outcome) => outcome.status === 'failed');
  process.exit(failed ? 1 : 0);
}

void main();
