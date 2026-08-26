'use strict';

async function dropTableIfPresent(knex, table) {
  if (await knex.schema.hasTable(table)) {
    await knex.schema.dropTable(table);
  }
}

module.exports.up = async (knex) => {
  if (
    (await knex.schema.hasTable('files_related_mph')) &&
    (await knex.schema.hasColumn('files_related_mph', 'related_type'))
  ) {
    await knex('files_related_mph').where('related_type', 'api::author.author').delete();
  }

  // Relation tables must be removed before the collection tables they reference.
  for (const table of [
    'posts_authors_lnk',
    'up_users_role_lnk',
    'up_permissions_role_lnk',
    'authors',
    'up_users',
    'up_permissions',
    'up_roles',
  ]) {
    await dropTableIfPresent(knex, table);
  }
};

// Removing these collection types is intentional and cannot be reversed without
// restoring their schemas and plugin first.
module.exports.down = async () => {};
