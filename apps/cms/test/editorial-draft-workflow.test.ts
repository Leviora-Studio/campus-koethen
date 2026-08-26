// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import contactArea from '../src/api/contact-area/content-types/contact-area/schema.json';
import contactPerson from '../src/api/contact-person/content-types/contact-person/schema.json';
import post from '../src/api/post/content-types/post/schema.json';
import channel from '../src/api/channel/content-types/channel/schema.json';
import tag from '../src/api/tag/content-types/tag/schema.json';
import publicCalendar from '../src/api/public-calendar/content-types/public-calendar/schema.json';

test('every editorial content type supports drafts before publication', () => {
  const schemas = {
    contactArea,
    contactPerson,
    post,
    channel,
    tag,
    publicCalendar,
  };

  for (const [name, schema] of Object.entries(schemas)) {
    assert.equal(
      schema.options.draftAndPublish,
      true,
      `${name} must not make a saved editorial change public immediately`,
    );
  }
});
