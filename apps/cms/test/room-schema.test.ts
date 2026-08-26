// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import roomSchema from '../src/api/room/content-types/room/schema.json';

test('room stores only catalogue identity and editorial overlay fields', () => {
  assert.deepEqual(Object.keys(roomSchema.attributes), [
    'editorLabel',
    'roomKey',
    'catalogActive',
    'displayNameDe',
    'displayNameEn',
    'descriptionDe',
    'descriptionEn',
    'isVisible',
    'contactPersons',
    'contactAreas',
  ]);
});

test('editorLabel is the first string field so Strapi uses it as the default main field', () => {
  const firstString = Object.entries(roomSchema.attributes).find(([, attribute]) => {
    return (attribute as { type: string }).type === 'string';
  });
  assert.equal(firstString?.[0], 'editorLabel');
});

test('rooms stay live references without draft and publish', () => {
  assert.equal(roomSchema.options.draftAndPublish, false);
});
