// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import channelSchema from '../src/api/channel/content-types/channel/schema.json';
import locationSchema from '../src/api/location/content-types/location/schema.json';
import publicCalendarSchema from '../src/api/public-calendar/content-types/public-calendar/schema.json';

type Attribute = {
  type: string;
  relation?: string;
  target?: string;
  inversedBy?: string;
  mappedBy?: string;
  required?: boolean;
  unique?: boolean;
  regex?: string;
  default?: unknown;
  pluginOptions?: { i18n: { localized: boolean } };
};

const attributes = locationSchema.attributes as Record<string, Attribute>;

test('location stores only name, slug, active state and its channel and calendar relations', () => {
  assert.equal(locationSchema.info.singularName, 'location');
  assert.deepEqual(Object.keys(attributes), ['name', 'slug', 'isActive', 'channels', 'calendars']);
  assert.equal(attributes.name.type, 'string');
  assert.equal(attributes.name.required, true);
});

test('location has a required, unique, slug-shaped slug and defaults to active', () => {
  const slug = attributes.slug;
  assert.equal(slug.required, true);
  assert.equal(slug.unique, true);
  assert.match('koethen', new RegExp(slug.regex!));
  assert.doesNotMatch('Köthen', new RegExp(slug.regex!));
  assert.equal(attributes.isActive.type, 'boolean');
  assert.equal(attributes.isActive.default, true);
});

test('a location is a place name shared by all language versions', () => {
  assert.equal(
    (locationSchema as { pluginOptions?: { i18n?: { localized?: boolean } } }).pluginOptions?.i18n
      ?.localized ?? false,
    false,
  );
});

for (const [label, schema, inverse] of [
  ['channel', channelSchema, 'channels'],
  ['public calendar', publicCalendarSchema, 'calendars'],
] as const) {
  test(`${label} has an optional, non-localised location`, () => {
    const location = (schema.attributes as Record<string, Attribute>).location;
    assert.equal(location.relation, 'manyToOne');
    assert.equal(location.target, 'api::location.location');
    assert.equal(location.inversedBy, inverse);
    assert.notEqual(location.required, true, 'existing entries stay without location');
    assert.equal(location.pluginOptions?.i18n.localized, false);

    const back = attributes[inverse];
    assert.equal(back.relation, 'oneToMany');
    assert.equal(
      back.target,
      schema === channelSchema ? 'api::channel.channel' : 'api::public-calendar.public-calendar',
    );
    assert.equal(back.mappedBy, 'location');
  });
}
