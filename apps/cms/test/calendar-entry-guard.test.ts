import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createCalendarEntryGuard,
  validateCalendarEntry,
} from '../src/editorial/calendar-entry-guard';
const demo = {
  start: '2026-11-16T10:00:00Z',
  end: '2026-11-16T11:00:00Z',
  timeZone: 'Europe/Berlin',
};
test('calendar entries require valid periods, IANA zones and exclusive UTC all-day dates', () => {
  assert.doesNotThrow(() => validateCalendarEntry(demo));
  assert.throws(() => validateCalendarEntry({ ...demo, end: demo.start }));
  assert.throws(() => validateCalendarEntry({ ...demo, timeZone: 'invalid' }));
  assert.throws(() => validateCalendarEntry({ ...demo, allDay: true }));
  assert.doesNotThrow(() =>
    validateCalendarEntry({
      ...demo,
      start: '2026-11-16T00:00:00Z',
      end: '2026-11-17T00:00:00Z',
      allDay: true,
    }),
  );
});

test('new translations inherit shared timing fields before validation', async () => {
  const calls: string[] = [];
  const guard = createCalendarEntryGuard({
    documents: () => ({
      findOne: async ({ locale }: { locale: string }) => {
        calls.push(locale);
        return locale === 'de' ? demo : null;
      },
    }),
  } as never);
  let continued = false;
  await guard(
    {
      uid: 'api::calendar-entry.calendar-entry',
      action: 'update',
      params: { documentId: 'demo-entry', locale: 'en', data: { title: 'Demo English title' } },
    },
    async () => {
      continued = true;
    },
  );
  assert.equal(continued, true);
  assert.deepEqual(calls, ['en', 'de']);
});
test('bulk publication validates every selected draft and never calls findOne with a wildcard', async () => {
  const guard = createCalendarEntryGuard({
    documents: () => ({
      findMany: async () => [demo, { ...demo, timeZone: 'invalid' }],
      findOne: async () => {
        throw new Error('Must not use findOne for a wildcard');
      },
    }),
  } as never);
  await assert.rejects(
    guard(
      {
        uid: 'api::calendar-entry.calendar-entry',
        action: 'publish',
        params: { documentId: 'demo-entry', locale: '*' },
      },
      async () => {},
    ),
  );
});
