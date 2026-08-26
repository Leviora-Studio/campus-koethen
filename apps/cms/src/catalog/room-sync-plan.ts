// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/**
 * Pure diff planning for the room catalogue sync.
 *
 * Deliberately free of Strapi: the planner sees plain records in and produces a
 * plan out, so every guarantee that actually matters — create/update/unchanged/
 * deactivate, "editorial content is never touched", "a dry run writes nothing",
 * "running twice changes nothing" — is testable without a database.
 *
 * Persistence is injected through {@link RoomWriter}, which the real sync
 * implements against the Strapi document service.
 */

import { CATALOG_MANAGED_FIELDS } from './room-guard';

/** One room as the map catalogue defines it. */
export interface CatalogRoom {
  roomKey: string;
  editorLabel: string;
}

/** One room as it currently exists in the CMS. */
export interface ExistingRoom extends CatalogRoom {
  documentId: string;
  catalogActive: boolean;
  /** Editorial fields may be present; they are never read by the planner. */
  [editorial: string]: unknown;
}

export type PlanEntry =
  | { kind: 'create'; roomKey: string; data: Record<string, unknown> }
  | {
      kind: 'update';
      roomKey: string;
      documentId: string;
      data: Record<string, unknown>;
      changedFields: string[];
    }
  | { kind: 'unchanged'; roomKey: string }
  | { kind: 'deactivate'; roomKey: string; documentId: string };

export interface SyncPlan {
  entries: PlanEntry[];
  summary: { create: number; update: number; unchanged: number; deactivate: number };
}

export interface RoomWriter {
  create(data: Record<string, unknown>): Promise<void>;
  update(documentId: string, data: Record<string, unknown>): Promise<void>;
  deactivate(documentId: string, roomKey: string): Promise<void>;
}

/** Catalogue-owned fields minus the activity flag, which is handled separately. */
const COMPARED_FIELDS = CATALOG_MANAGED_FIELDS.filter(
  (field) => field !== 'catalogActive',
) as readonly (keyof CatalogRoom)[];

function desiredData(room: CatalogRoom, catalogActive: boolean): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const field of COMPARED_FIELDS) {
    data[field] = room[field];
  }
  data.catalogActive = catalogActive;
  return data;
}

/**
 * Computes the plan.
 *
 * Ordering is by `roomKey` so a plan — and therefore a dry-run report — is
 * reproducible and reviewable.
 */
export function planRoomSync(
  catalogRooms: readonly CatalogRoom[],
  existingRooms: readonly ExistingRoom[],
): SyncPlan {
  const byKey = new Map<string, CatalogRoom>();
  for (const room of catalogRooms) {
    if (byKey.has(room.roomKey)) {
      throw new Error(`Refusing to sync: duplicate roomKey "${room.roomKey}" in the catalogue`);
    }
    byKey.set(room.roomKey, room);
  }

  const existingByKey = new Map<string, ExistingRoom>();
  for (const room of existingRooms) {
    if (existingByKey.has(room.roomKey)) {
      throw new Error(`Refusing to sync: duplicate roomKey "${room.roomKey}" in the CMS`);
    }
    existingByKey.set(room.roomKey, room);
  }

  const entries: PlanEntry[] = [];

  for (const [roomKey, room] of byKey) {
    const existing = existingByKey.get(roomKey);

    if (!existing) {
      entries.push({ kind: 'create', roomKey, data: desiredData(room, true) });
      continue;
    }

    const changedFields = COMPARED_FIELDS.filter(
      (field) => existing[field] !== room[field],
    ) as string[];
    if (existing.catalogActive !== true) {
      changedFields.push('catalogActive');
    }

    if (changedFields.length === 0) {
      entries.push({ kind: 'unchanged', roomKey });
      continue;
    }

    entries.push({
      kind: 'update',
      roomKey,
      documentId: existing.documentId,
      data: desiredData(room, true),
      changedFields,
    });
  }

  for (const [roomKey, existing] of existingByKey) {
    if (byKey.has(roomKey)) continue;
    // Never delete: editorial texts and contact relations live on this row.
    if (existing.catalogActive === false) {
      entries.push({ kind: 'unchanged', roomKey });
    } else {
      entries.push({ kind: 'deactivate', roomKey, documentId: existing.documentId });
    }
  }

  entries.sort((a, b) => a.roomKey.localeCompare(b.roomKey));

  return {
    entries,
    summary: {
      create: entries.filter((e) => e.kind === 'create').length,
      update: entries.filter((e) => e.kind === 'update').length,
      unchanged: entries.filter((e) => e.kind === 'unchanged').length,
      deactivate: entries.filter((e) => e.kind === 'deactivate').length,
    },
  };
}

/** Executes a plan. With `dryRun` the writer is never called. */
export async function applyPlan(
  plan: SyncPlan,
  writer: RoomWriter,
  options: { dryRun: boolean },
): Promise<void> {
  if (options.dryRun) return;

  for (const entry of plan.entries) {
    switch (entry.kind) {
      case 'create':
        await writer.create(entry.data);
        break;
      case 'update':
        await writer.update(entry.documentId, entry.data);
        break;
      case 'deactivate':
        await writer.deactivate(entry.documentId, entry.roomKey);
        break;
      case 'unchanged':
        break;
    }
  }
}

/** A short, reviewable report. Contains keys and counts, never field values. */
export function formatPlan(plan: SyncPlan, { dryRun }: { dryRun: boolean }): string {
  const lines: string[] = [];
  lines.push(
    `${dryRun ? 'DRY RUN — nothing is written' : 'Applying room catalogue sync'}: ` +
      `${plan.summary.create} create, ${plan.summary.update} update, ` +
      `${plan.summary.unchanged} unchanged, ${plan.summary.deactivate} deactivate`,
  );
  for (const entry of plan.entries) {
    switch (entry.kind) {
      case 'create':
        lines.push(`  + create      ${entry.roomKey}`);
        break;
      case 'update':
        lines.push(`  ~ update      ${entry.roomKey} (${entry.changedFields.join(', ')})`);
        break;
      case 'deactivate':
        lines.push(`  - deactivate  ${entry.roomKey}`);
        break;
      case 'unchanged':
        break;
    }
  }
  if (plan.summary.unchanged > 0) {
    lines.push(`  = ${plan.summary.unchanged} unchanged`);
  }
  return lines.join('\n');
}
