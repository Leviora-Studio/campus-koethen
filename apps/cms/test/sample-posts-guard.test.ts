// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { assertSamplePostsMayRun } from '../scripts/seed-sample-posts';

test('sample posts can never be written by a production process', () => {
  assert.throws(() => assertSamplePostsMayRun('production'), /Refusing to seed sample posts/);
  assert.throws(() => assertSamplePostsMayRun(''), /Refusing to seed sample posts/);
});

test('sample posts remain available in explicit local environments', () => {
  assert.doesNotThrow(() => assertSamplePostsMayRun('development'));
  assert.doesNotThrow(() => assertSamplePostsMayRun('test'));
});
