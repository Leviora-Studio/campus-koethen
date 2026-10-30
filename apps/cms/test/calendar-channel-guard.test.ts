// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  CalendarChannelLookup,
  createCalendarChannelGuard,
} from '../src/editorial/calendar-channel-guard';
import { CHANNEL_UID, POST_UID, PUBLIC_CALENDAR_UID } from '../src/editorial/post-guard';

/**
 * Fictional demo documents: channel `ch-fsr` already has calendar `cal-a`;
 * channel `ch-stura` and calendar `cal-b` are still unassigned.
 */
const lookup: CalendarChannelLookup = {
  async calendarOfChannel(channel) {
    return channel === 'ch-fsr' ? { documentId: 'cal-a', name: 'FSR-Termine' } : null;
  },
  async channelOfCalendar(calendar) {
    return calendar === 'cal-a' ? { documentId: 'ch-fsr', name: 'Demo-FSR' } : null;
  },
};

async function run(
  uid: string,
  documentId: string | undefined,
  data: Record<string, unknown>,
): Promise<boolean> {
  let calledNext = false;
  await createCalendarChannelGuard(lookup)(
    { uid, action: documentId ? 'update' : 'create', params: { documentId, data } },
    async () => {
      calledNext = true;
    },
  );
  return calledNext;
}

test('a calendar cannot take a channel that already has another calendar', async () => {
  for (const channel of [
    'ch-fsr',
    { documentId: 'ch-fsr' },
    { connect: [{ documentId: 'ch-fsr', locale: 'de' }] },
    { set: [{ documentId: 'ch-fsr' }] },
  ]) {
    await assert.rejects(
      run(PUBLIC_CALENDAR_UID, 'cal-b', { channel }),
      (error: Error) => error.name === 'ValidationError' && /FSR-Termine/.test(error.message),
      `rejected for ${JSON.stringify(channel)}`,
    );
  }
  await assert.rejects(run(PUBLIC_CALENDAR_UID, undefined, { channel: 'ch-fsr' }));
});

test('a channel cannot take a calendar that already belongs to another channel', async () => {
  await assert.rejects(
    run(CHANNEL_UID, 'ch-stura', { publicCalendar: { connect: [{ documentId: 'cal-a' }] } }),
    (error: Error) => error.name === 'ValidationError' && /Demo-FSR/.test(error.message),
  );
});

test('free and unchanged assignments pass', async () => {
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-b', { channel: 'ch-stura' }), true);
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-a', { channel: 'ch-fsr' }), true);
  assert.equal(await run(CHANNEL_UID, 'ch-fsr', { publicCalendar: 'cal-a' }), true);
  assert.equal(await run(CHANNEL_UID, 'ch-stura', { publicCalendar: 'cal-b' }), true);
});

test('removing an assignment and unrelated writes pass', async () => {
  assert.equal(
    await run(PUBLIC_CALENDAR_UID, 'cal-b', {
      channel: { disconnect: [{ documentId: 'ch-fsr' }] },
    }),
    true,
  );
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-b', { channel: null }), true);
  assert.equal(await run(PUBLIC_CALENDAR_UID, 'cal-b', { name: 'Neu' }), true);
  assert.equal(await run(POST_UID, undefined, { channel: 'ch-fsr' }), true);
});
