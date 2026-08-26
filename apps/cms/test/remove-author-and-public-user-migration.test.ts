import assert from 'node:assert/strict';
import test from 'node:test';

// The migration is CommonJS because Strapi's migration resolver requires it.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const migration =
  require('../database/migrations/2026.08.25T19.30.00.remove-author-and-public-user.js') as {
    up(knex: unknown): Promise<void>;
  };

test('author and public user tables are removed without touching admin users', async () => {
  const tables = new Set([
    'files_related_mph',
    'posts_authors_lnk',
    'authors',
    'up_users_role_lnk',
    'up_permissions_role_lnk',
    'up_users',
    'up_permissions',
    'up_roles',
    'admin_users',
  ]);
  const deletedRelations: Array<[string, string]> = [];
  const dropped: string[] = [];

  const schema = {
    hasTable: async (table: string) => tables.has(table),
    hasColumn: async (table: string, column: string) =>
      table === 'files_related_mph' && column === 'related_type',
    dropTable: async (table: string) => {
      tables.delete(table);
      dropped.push(table);
    },
  };

  const knex = Object.assign(
    (_table: string) => ({
      where: (column: string, value: string) => ({
        delete: async () => deletedRelations.push([column, value]),
      }),
    }),
    { schema },
  );

  await migration.up(knex);

  assert.deepEqual(deletedRelations, [['related_type', 'api::author.author']]);
  assert.deepEqual(dropped, [
    'posts_authors_lnk',
    'up_users_role_lnk',
    'up_permissions_role_lnk',
    'authors',
    'up_users',
    'up_permissions',
    'up_roles',
  ]);
  assert.equal(tables.has('admin_users'), true);
});
