/**
 * Synchronises the canonical map catalogue into the Strapi `room` collection.
 *
 * Usage:
 *   pnpm --filter @campus/cms rooms:sync -- --dry-run
 *   pnpm --filter @campus/cms rooms:sync
 *
 * Contract, all covered by tests in test/room-sync-plan.test.ts:
 *   - an invalid catalogue aborts BEFORE any CMS write;
 *   - new roomKeys are created, known ones only have catalogue fields refreshed;
 *   - editorial fields and contact relations are never written;
 *   - a room that disappeared is deactivated, never deleted;
 *   - a reappearing room is reactivated;
 *   - repeated runs are a no-op;
 *   - --dry-run writes nothing.
 *
 * This is an explicit, human-triggered maintenance command. It is NOT wired
 * into the Strapi bootstrap and never runs from CI: mutating a live CMS must
 * stay a deliberate act.
 */

import { createStrapi } from '@strapi/strapi';

import { runAsCatalogSync } from '../src/catalog/catalog-scope';
import {
  applyPlan,
  formatPlan,
  planRoomSync,
  type CatalogRoom,
  type ExistingRoom,
  type RoomWriter,
} from '../src/catalog/room-sync-plan';
import { parseSyncArgs } from '../src/catalog/sync-args';

const ROOM_UID = 'api::room.room';

interface DocumentService {
  findMany(params: Record<string, unknown>): Promise<Record<string, unknown>[]>;
  create(params: { data: Record<string, unknown> }): Promise<unknown>;
  update(params: { documentId: string; data: Record<string, unknown> }): Promise<unknown>;
}

/** Loads and validates the canonical catalogue. Throws on any problem. */
async function loadCatalogRooms(): Promise<{ rooms: CatalogRoom[]; mapVersion: string }> {
  // The map package is ESM; a dynamic import keeps this CommonJS script simple.
  const map = await import('@campus/map');

  const { catalog, problems } = map.loadCanonical();
  if (problems.length > 0) {
    throw new Error(
      `The map catalogue is invalid — refusing to touch the CMS:\n  - ${problems.join('\n  - ')}`,
    );
  }
  return { rooms: map.toFlatRooms(catalog), mapVersion: catalog.mapVersion };
}

async function main(): Promise<void> {
  const { dryRun } = parseSyncArgs(process.argv);

  // Validation first: an invalid catalogue must never reach the CMS, and
  // failing here means Strapi was not even started.
  const { rooms, mapVersion } = await loadCatalogRooms();
  process.stderr.write(`Catalogue valid — ${rooms.length} room(s), mapVersion ${mapVersion}.\n`);

  const app = await createStrapi({ appDir: process.cwd(), distDir: 'dist' }).load();

  try {
    const documents = app.documents(ROOM_UID) as unknown as DocumentService;

    const existingRaw = await documents.findMany({
      // Relations are deliberately NOT populated: the planner must never see
      // editorial data, let alone be able to write it back.
      fields: ['roomKey', 'editorLabel', 'catalogActive'],
      pagination: { pageSize: 1000 },
    });

    const existing = existingRaw as unknown as ExistingRoom[];
    const plan = planRoomSync(rooms, existing);

    process.stdout.write(`${formatPlan(plan, { dryRun })}\n`);

    if (dryRun) {
      process.stderr.write('Dry run finished — the CMS was not modified.\n');
      return;
    }

    const writer: RoomWriter = {
      create: async (data) => {
        await documents.create({ data });
      },
      update: async (documentId, data) => {
        await documents.update({ documentId, data });
      },
      deactivate: async (documentId) => {
        // Deactivate, never delete — editorial texts and contact relations
        // live on this row and must survive a catalogue change.
        await documents.update({ documentId, data: { catalogActive: false } });
      },
    };

    // The ONLY place allowed to write catalogue-managed fields.
    await runAsCatalogSync(async () => {
      await applyPlan(plan, writer, { dryRun: false });
    });

    process.stderr.write('Room catalogue sync finished.\n');
  } finally {
    await app.destroy();
  }
}

void main()
  .then(() => process.exit(0))
  .catch((error: unknown) => {
    // Raw framework/database errors can contain connection details or record
    // values. The command result stays useful without echoing that payload.
    void error;
    process.stderr.write('Room sync failed; inspect the local CMS logs.\n');
    process.exit(1);
  });
