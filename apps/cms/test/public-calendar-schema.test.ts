// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import publicCalendarSchema from '../src/api/public-calendar/content-types/public-calendar/schema.json';

test('public calendars have a validated, non-localized fallback colour', () => {
  const attributes = publicCalendarSchema.attributes as Record<string, unknown>;

  assert.deepEqual(attributes.colorHex, {
    type: 'string',
    regex: '^#[0-9a-fA-F]{6}$',
    pluginOptions: { i18n: { localized: false } },
  });
});
