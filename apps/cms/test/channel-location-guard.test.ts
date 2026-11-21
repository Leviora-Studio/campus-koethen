// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ChannelLocationLookup,
  LinkedState,
  createChannelLocationGuard,
} from '../src/editorial/channel-location-guard';
import {
  CHANNEL_UID,
  LOCATION_UID,
  POST_UID,
  PUBLIC_CALENDAR_UID,
} from '../src/editorial/post-guard';

/**
 * Fictional demo documents, all draft state:
 *
 *   loc-a "Demo-Ort A", loc-b "Demo-Ort B"
 *   ch-a   (loc-a)  ↔ cal-a (loc-a)     consistent pair
 *   ch-old (none)   ↔ cal-old (none)    pair from before locations existed
 *   ch-half (loc-a) ↔ cal-half (none)   pair halfway through being assigned
 *   ch-free-a (loc-a), ch-free-b (loc-b), ch-free-none (none)  without calendar
 *   cal-free-a (loc-a), cal-free-b (loc-b), cal-free-none (none) without channel
 */
const locations = {
  'loc-a': { documentId: 'loc-a', name: 'Demo-Ort A' },
  'loc-b': { documentId: 'loc-b', name: 'Demo-Ort B' },
};
type LocationId = keyof typeof locations;

const channels: Record<string, [LocationId | null, string | null]> = {
  'ch-a': ['loc-a', 'cal-a'],
  'ch-old': [null, 'cal-old'],
  'ch-half': ['loc-a', 'cal-half'],
  'ch-free-a': ['loc-a', null],
  'ch-free-b': ['loc-b', null],
  'ch-free-none': [null, null],
};
const calendars: Record<string, [LocationId | null, string | null]> = {
  'cal-a': ['loc-a', 'ch-a'],
  'cal-old': [null, 'ch-old'],
  'cal-half': [null, 'ch-half'],
  'cal-free-a': ['loc-a', null],
  'cal-free-b': ['loc-b', null],
  'cal-free-none': [null, null],
};

function side(table: typeof channels, id: string) {
  const [location] = table[id];
  return { documentId: id, name: `Demo ${id}`, location: location ? locations[location] : null };
}

const lookup: ChannelLocationLookup = {
  async state(uid, ref): Promise<LinkedState | null> {
    const [own, other] = uid === CHANNEL_UID ? [channels, calendars] : [calendars, channels];
    const id = String(ref);
    if (!own[id]) return null;
    const partner = own[id][1];
    return { ...side(own, id), partner: partner ? side(other, partner) : null };
  },
  async location(ref) {
    return locations[String(ref) as LocationId] ?? null;
  },
};

async function run(
  uid: string,
  documentId: string | undefined,
  data: Record<string, unknown>,
): Promise<boolean> {
  let calledNext = false;
  await createChannelLocationGuard(lookup)(
    { uid, action: documentId ? 'update' : 'create', params: { documentId, data } },
    async () => {
      calledNext = true;
    },
  );
  return calledNext;
}

const missing = (error: Error) =>
  error.name === 'ValidationError' && /denselben Standort/.test(error.message);
const different = (error: Error) =>
  error.name === 'ValidationError' &&
  /Demo-Ort A/.test(error.message) &&
  /Demo-Ort B/.test(error.message);

test('linking a calendar and a channel with the same location passes', async () => {
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-free-a', { channel: 'ch-free-a' }), true);
  assert.equal(
    await run(CHANNEL_UID, 'ch-free-b', {
      publicCalendar: { connect: [{ documentId: 'cal-free-b' }], disconnect: [] },
    }),
    true,
  );
});

test('linking a calendar and a channel with different locations is refused', async () => {
  for (const channel of [
    'ch-free-b',
    { documentId: 'ch-free-b' },
    { connect: [{ documentId: 'ch-free-b', locale: 'de' }] },
    { set: [{ documentId: 'ch-free-b' }] },
  ]) {
    await assert.rejects(
      run(PUBLIC_CALENDAR_UID, 'cal-free-a', { channel }),
      different,
      `rejected for ${JSON.stringify(channel)}`,
    );
  }
  await assert.rejects(run(CHANNEL_UID, 'ch-free-a', { publicCalendar: 'cal-free-b' }), different);
});

test('linking is refused while the channel, the calendar or both have no location', async () => {
  await assert.rejects(
    run(PUBLIC_CALENDAR_UID, 'cal-free-a', { channel: 'ch-free-none' }),
    missing,
  );
  await assert.rejects(
    run(PUBLIC_CALENDAR_UID, 'cal-free-none', { channel: 'ch-free-a' }),
    missing,
  );
  await assert.rejects(
    run(CHANNEL_UID, 'ch-free-none', { publicCalendar: 'cal-free-none' }),
    missing,
  );
  await assert.rejects(
    run(CHANNEL_UID, undefined, { name: 'Neu', publicCalendar: 'cal-free-a' }),
    missing,
    'a new channel without location cannot take a calendar',
  );
});

test('a location set in the same write counts for the new link', async () => {
  assert.equal(
    await run(PUBLIC_CALENDAR_UID, 'cal-free-none', {
      location: { connect: [{ documentId: 'loc-a' }] },
      channel: 'ch-free-a',
    }),
    true,
  );
  assert.equal(
    await run(CHANNEL_UID, undefined, {
      name: 'Neu',
      location: 'loc-b',
      publicCalendar: 'cal-free-b',
    }),
    true,
  );
  await assert.rejects(
    run(CHANNEL_UID, 'ch-free-a', { location: 'loc-b', publicCalendar: 'cal-free-a' }),
    different,
  );
  await assert.rejects(
    run(CHANNEL_UID, 'ch-free-a', { location: null, publicCalendar: 'cal-free-a' }),
    missing,
  );
});

test('a linked channel or calendar cannot move to a location its partner does not have', async () => {
  await assert.rejects(run(CHANNEL_UID, 'ch-a', { location: 'loc-b' }), different);
  await assert.rejects(
    run(PUBLIC_CALENDAR_UID, 'cal-a', { location: { connect: [{ documentId: 'loc-b' }] } }),
    different,
  );
  await assert.rejects(run(PUBLIC_CALENDAR_UID, 'cal-half', { location: 'loc-b' }), different);
});

test('existing pairs can be given their location one side after the other', async () => {
  assert.equal(await run(CHANNEL_UID, 'ch-old', { location: 'loc-b' }), true);
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-old', { location: 'loc-a' }), true);
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-half', { location: 'loc-a' }), true);
  assert.equal(await run(CHANNEL_UID, 'ch-a', { location: 'loc-a' }), true);
});

test('unrelated edits of pairs without location stay possible', async () => {
  assert.equal(await run(CHANNEL_UID, 'ch-old', { name: 'Neu' }), true);
  assert.equal(
    await run(CHANNEL_UID, 'ch-old', { publicCalendar: { connect: [], disconnect: [] } }),
    true,
  );
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-old', { channel: 'ch-old' }), true);
  assert.equal(await run(POST_UID, undefined, { channel: 'ch-free-b' }), true);
});

test('unlinking, and changing location together with unlinking, pass', async () => {
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-a', { channel: null }), true);
  assert.equal(
    await run(CHANNEL_UID, 'ch-a', {
      location: 'loc-b',
      publicCalendar: { disconnect: [{ documentId: 'cal-a' }] },
    }),
    true,
  );
});

test('assigning channels or calendars from the location side follows the same rule', async () => {
  assert.equal(
    await run(LOCATION_UID, 'loc-a', { channels: { connect: [{ documentId: 'ch-old' }] } }),
    true,
  );
  assert.equal(await run(LOCATION_UID, 'loc-a', { calendars: [{ documentId: 'cal-half' }] }), true);
  await assert.rejects(
    run(LOCATION_UID, 'loc-b', { calendars: { connect: [{ documentId: 'cal-half' }] } }),
    different,
  );
  await assert.rejects(
    run(LOCATION_UID, 'loc-b', { channels: { set: [{ documentId: 'ch-a' }] } }),
    different,
  );
  assert.equal(
    await run(LOCATION_UID, 'loc-b', {
      channels: { connect: [{ documentId: 'ch-a' }] },
      calendars: { connect: [{ documentId: 'cal-a' }] },
    }),
    true,
    'moving a whole pair at once keeps it consistent',
  );
  await assert.rejects(
    run(LOCATION_UID, undefined, { name: 'Neu', channels: ['ch-a'] }),
    (error: Error) => error.name === 'ValidationError' && /Demo-Ort A/.test(error.message),
  );
  assert.equal(
    await run(LOCATION_UID, 'loc-a', { channels: { disconnect: [{ documentId: 'ch-a' }] } }),
    true,
  );
});

test('validation and writing run in one transaction', async () => {
  let inTransaction = false;
  const guard = createChannelLocationGuard({
    ...lookup,
    async transaction(work) {
      inTransaction = true;
      try {
        return await work();
      } finally {
        inTransaction = false;
      }
    },
    async state(uid, ref) {
      assert.equal(inTransaction, true);
      return lookup.state(uid, ref);
    },
  });
  await assert.rejects(
    guard(
      {
        uid: CHANNEL_UID,
        action: 'update',
        params: { documentId: 'ch-a', data: { location: 'loc-b' } },
      },
      async () => {
        throw new Error('Conflict must be refused before the write');
      },
    ),
    different,
  );
  assert.equal(inTransaction, false);
});
