import assert from 'node:assert/strict';
import test from 'node:test';

// The migration is CommonJS because Strapi's migration resolver requires it.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const migration =
  require('../database/migrations/2026.08.25T17.30.00.simplify-editorial-fields.js') as {
    up(knex: unknown): Promise<void>;
  };

test('editorial cleanup migration renames values before dropping obsolete columns', async () => {
  const tables = new Map<string, Set<string>>([
    [
      'public_calendars',
      new Set([
        'show_description',
        'show_location',
        'description',
        'icon_key',
        'owner_contact',
        'attribution',
        'time_zone',
      ]),
    ],
    ['contact_areas', new Set(['appointment_url', 'is_demo_content', 'icon_key'])],
    ['posts', new Set(['teaser', 'is_pinned', 'event_time_zone'])],
    ['tags', new Set(['description', 'icon_key', 'color_hex', 'sort_order'])],
  ]);

  const normalized: string[] = [];
  const schema = {
    hasTable: async (table: string) => tables.has(table),
    hasColumn: async (table: string, column: string) => tables.get(table)?.has(column) ?? false,
    alterTable: async (
      table: string,
      callback: (builder: {
        renameColumn(from: string, to: string): void;
        dropColumns(...columns: string[]): void;
      }) => void,
    ) => {
      const columns = tables.get(table)!;
      callback({
        renameColumn(from, to) {
          columns.delete(from);
          columns.add(to);
        },
        dropColumns(...removed) {
          for (const column of removed) columns.delete(column);
        },
      });
    },
  };

  const knex = Object.assign(
    (_table: string) => ({
      whereNotIn: (_column: string, _values: string[]) => ({
        update: async () => normalized.push('invalid'),
      }),
      whereNull: (_column: string) => ({ update: async () => normalized.push('null') }),
    }),
    { schema },
  );

  await migration.up(knex);

  assert.ok(tables.get('public_calendars')?.has('include_event_description'));
  assert.ok(tables.get('public_calendars')?.has('include_event_location'));
  assert.ok(tables.get('contact_areas')?.has('appointment_booking_url'));
  assert.deepEqual(normalized, ['invalid', 'null']);
  assert.deepEqual([...tables.get('posts')!], []);
  assert.deepEqual([...tables.get('tags')!], []);
});
