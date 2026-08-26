// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import channelSchema from '../src/api/channel/content-types/channel/schema.json';

test('channels expose colour but no icon field in Strapi', () => {
  const attributes = channelSchema.attributes as Record<string, unknown>;
  const colorHex = attributes.colorHex as {
    type: string;
    required: boolean;
    regex: string;
  };

  assert.equal('iconKey' in attributes, false);
  assert.equal(colorHex.type, 'string');
  assert.equal(colorHex.required, true);
  assert.match('#C2185B', new RegExp(colorHex.regex));
});

test('channel name is a shared proper name while its description stays localised', () => {
  const name = channelSchema.attributes.name as {
    pluginOptions: { i18n: { localized: boolean } };
  };
  const description = channelSchema.attributes.description as {
    pluginOptions: { i18n: { localized: boolean } };
  };

  assert.equal(name.pluginOptions.i18n.localized, false);
  assert.equal(description.pluginOptions.i18n.localized, true);
});

test('channel has a oneToOne relation to public-calendar', () => {
  const publicCalendar = channelSchema.attributes.publicCalendar as {
    relation: string;
    target: string;
    inversedBy: string;
    pluginOptions: { i18n: { localized: boolean } };
  };

  assert.equal(publicCalendar.relation, 'oneToOne');
  assert.equal(publicCalendar.target, 'api::public-calendar.public-calendar');
  assert.equal(publicCalendar.inversedBy, 'channel');
  assert.equal(publicCalendar.pluginOptions.i18n.localized, false);
});
