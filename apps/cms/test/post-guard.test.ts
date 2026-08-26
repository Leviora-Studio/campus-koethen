// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createEditorialGuard,
  ensurePrimaryChannelInChannels,
  validateEventDates,
  validatePostPublishRequirements,
  validatePostSlug,
  EditorialValidationError,
  POST_UID,
} from '../src/editorial/post-guard';

test('reserved slugs channels, tags, and events are rejected', () => {
  for (const reserved of ['channels', 'tags', 'events', 'CHANNELS', 'Events']) {
    assert.throws(
      () => validatePostSlug(reserved),
      EditorialValidationError,
      `slug ${reserved} must be rejected`,
    );
  }
  assert.doesNotThrow(() => validatePostSlug('summer-festival-2026'));
  assert.doesNotThrow(() => validatePostSlug('campus-news-update'));
});

test('eventEnd must be strictly after eventStart', () => {
  assert.throws(
    () => validateEventDates('2026-09-01T10:00:00.000Z', '2026-09-01T09:00:00.000Z'),
    EditorialValidationError,
  );
  assert.throws(
    () => validateEventDates('2026-09-01T10:00:00.000Z', '2026-09-01T10:00:00.000Z'),
    EditorialValidationError,
  );
  assert.doesNotThrow(() =>
    validateEventDates('2026-09-01T10:00:00.000Z', '2026-09-01T12:00:00.000Z'),
  );
  assert.doesNotThrow(() => validateEventDates('2026-09-01T10:00:00.000Z', null));
  assert.doesNotThrow(() => validateEventDates(null, null));
});

test('ensurePrimaryChannelInChannels adds primaryChannel to channels deterministically', () => {
  const data1: Record<string, unknown> = {
    primaryChannel: 'c-main',
  };
  ensurePrimaryChannelInChannels(data1);
  assert.deepEqual(data1['channels'], ['c-main']);

  const data2: Record<string, unknown> = {
    primaryChannel: 'c-main',
    channels: ['c-other'],
  };
  ensurePrimaryChannelInChannels(data2);
  assert.deepEqual(data2['channels'], ['c-other', 'c-main']);

  const data3: Record<string, unknown> = {
    primaryChannel: 'c-main',
    channels: ['c-main', 'c-other'],
  };
  ensurePrimaryChannelInChannels(data3);
  assert.deepEqual(data3['channels'], ['c-main', 'c-other'], 'no duplicate added');
});

test('ensurePrimaryChannelInChannels unwraps {connect: [...]} / {set: [...]} relation payloads', () => {
  // Regression: primaryChannel and channels can arrive Document-Service-style,
  // wrapped in {connect: [...]}. Merging the wrapper object itself (instead of
  // the item(s) it carries) produced a malformed `channels` payload that later
  // failed relation resolution with "Invalid relations".
  const data1: Record<string, unknown> = {
    primaryChannel: { connect: [{ documentId: 'doc-main' }] },
  };
  ensurePrimaryChannelInChannels(data1);
  assert.deepEqual(data1['channels'], [{ documentId: 'doc-main' }]);

  const data2: Record<string, unknown> = {
    primaryChannel: { connect: [{ documentId: 'doc-main' }] },
    channels: { connect: [{ documentId: 'doc-other' }] },
  };
  ensurePrimaryChannelInChannels(data2);
  assert.deepEqual(data2['channels'], {
    connect: [{ documentId: 'doc-other' }, { documentId: 'doc-main' }],
  });

  const data3: Record<string, unknown> = {
    primaryChannel: { connect: [{ documentId: 'doc-main' }] },
    channels: { connect: [{ documentId: 'doc-main' }, { documentId: 'doc-other' }] },
  };
  ensurePrimaryChannelInChannels(data3);
  assert.deepEqual(
    data3['channels'],
    { connect: [{ documentId: 'doc-main' }, { documentId: 'doc-other' }] },
    'no duplicate added',
  );

  const data4: Record<string, unknown> = {
    primaryChannel: { documentId: 'doc-main' },
    channels: [{ documentId: 'doc-other' }],
  };
  ensurePrimaryChannelInChannels(data4);
  assert.deepEqual(data4['channels'], [{ documentId: 'doc-other' }, { documentId: 'doc-main' }]);
});

test('publishing requires tag and primaryChannel', () => {
  assert.throws(
    () =>
      validatePostPublishRequirements({
        slug: 'valid-slug',
        primaryChannel: 'c-main',
      }),
    /without a tag/,
  );

  assert.throws(
    () =>
      validatePostPublishRequirements({
        slug: 'valid-slug',
        tag: 'news',
      }),
    /without a primaryChannel/,
  );

  assert.doesNotThrow(() =>
    validatePostPublishRequirements({
      slug: 'valid-slug',
      tag: { slug: 'news' },
      primaryChannel: 'c-main',
    }),
  );
});

test('publishing an event requires eventStart', () => {
  assert.throws(
    () =>
      validatePostPublishRequirements(
        {
          slug: 'valid-slug',
          tag: { slug: 'event' },
          primaryChannel: 'c-main',
        },
        'event',
      ),
    /without a valid eventStart/,
  );

  assert.doesNotThrow(() =>
    validatePostPublishRequirements(
      {
        slug: 'valid-slug',
        tag: { slug: 'event' },
        primaryChannel: 'c-main',
        eventStart: '2026-09-01T10:00:00.000Z',
      },
      'event',
    ),
  );
});

test('drafts allow incomplete fields through editorialGuard middleware', async () => {
  const guard = createEditorialGuard();
  let calledNext = false;

  const result = await guard(
    {
      uid: POST_UID,
      action: 'create',
      params: {
        data: {
          title: 'Draft Post Title',
          // no tag, no primaryChannel, incomplete draft
        },
      },
    },
    async () => {
      calledNext = true;
      return 'created-draft';
    },
  );

  assert.equal(calledNext, true);
  assert.equal(result, 'created-draft');
});
