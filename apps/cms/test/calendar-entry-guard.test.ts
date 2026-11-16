import assert from 'node:assert/strict';
import test from 'node:test';
import { validateCalendarEntry } from '../src/editorial/calendar-entry-guard';
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
