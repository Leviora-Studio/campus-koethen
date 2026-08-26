'use strict';

async function renameIfPresent(knex, table, from, to) {
  if (!(await knex.schema.hasTable(table))) return;
  const hasFrom = await knex.schema.hasColumn(table, from);
  const hasTo = await knex.schema.hasColumn(table, to);
  if (hasFrom && !hasTo) {
    await knex.schema.alterTable(table, (builder) => builder.renameColumn(from, to));
  }
}

async function dropIfPresent(knex, table, columns) {
  if (!(await knex.schema.hasTable(table))) return;
  const present = [];
  for (const column of columns) {
    if (await knex.schema.hasColumn(table, column)) present.push(column);
  }
  if (present.length > 0) {
    await knex.schema.alterTable(table, (builder) => builder.dropColumns(...present));
  }
}

module.exports.up = async (knex) => {
  await renameIfPresent(knex, 'public_calendars', 'show_description', 'include_event_description');
  await renameIfPresent(knex, 'public_calendars', 'show_location', 'include_event_location');
  await renameIfPresent(knex, 'contact_areas', 'appointment_url', 'appointment_booking_url');

  if (
    (await knex.schema.hasTable('contact_areas')) &&
    (await knex.schema.hasColumn('contact_areas', 'icon_key'))
  ) {
    const allowedIcons = [
      'campus',
      'faculty',
      'students-council',
      'service',
      'library',
      'canteen',
      'housing',
      'finance',
      'international',
      'health',
      'sports',
      'it',
      'career',
    ];
    await knex('contact_areas')
      .whereNotIn('icon_key', allowedIcons)
      .update({ icon_key: 'service' });
    await knex('contact_areas').whereNull('icon_key').update({ icon_key: 'service' });
  }

  await dropIfPresent(knex, 'public_calendars', [
    'description',
    'icon_key',
    'owner_contact',
    'attribution',
    'time_zone',
  ]);
  await dropIfPresent(knex, 'contact_areas', ['is_demo_content']);
  await dropIfPresent(knex, 'posts', ['teaser', 'is_pinned', 'event_time_zone']);
  await dropIfPresent(knex, 'tags', ['description', 'icon_key', 'color_hex', 'sort_order']);
};

module.exports.down = async (knex) => {
  await renameIfPresent(knex, 'public_calendars', 'include_event_description', 'show_description');
  await renameIfPresent(knex, 'public_calendars', 'include_event_location', 'show_location');
  await renameIfPresent(knex, 'contact_areas', 'appointment_booking_url', 'appointment_url');
};
