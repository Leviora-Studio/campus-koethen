// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import publicCalendarSchema from '../src/api/public-calendar/content-types/public-calendar/schema.json';

// A calendar's events take their colour from the channel it belongs to, so the
// calendar itself offers no colour choice that could disagree with it.
test('public calendars have no colour of their own', () => {
  const attributes = publicCalendarSchema.attributes as Record<string, unknown>;

  assert.equal('colorHex' in attributes, false);
});
