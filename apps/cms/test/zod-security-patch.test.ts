import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import type { z as Zod3 } from '../../backend/node_modules/zod/v3';
const fromUtils = createRequire(require.resolve('@strapi/utils'));
const { z } = fromUtils('zod') as { z: typeof Zod3 };

test('Strapi Zod 3 rejects oversized collections before validating elements', async () => {
  let calls = 0;
  const element = z.preprocess((v) => {
    calls++;
    return v;
  }, z.string());
  assert.equal(z.array(element).max(2).safeParse(['demo', 'demo', 'demo']).success, false);
  assert.equal(calls, 0);
  assert.equal((await z.array(element).safeParseAsync(Array(10001).fill('demo'))).success, false);
  assert.equal(calls, 0);
  assert.equal(
    z
      .set(element)
      .max(1)
      .safeParse(new Set(['demo-a', 'demo-b'])).success,
    false,
  );
  assert.equal(calls, 0);
  assert.equal(z.array(element).safeParse(['demo']).success, true);
});
test('Strapi Zod 3 bounds collected errors in both distributed module formats', () => {
  const result = z.array(z.string()).safeParse(Array(2000).fill(null));
  assert.equal(result.success, false);
  if (!result.success) assert.ok(result.error.issues.length <= 1000);
  const directory = path.dirname(fromUtils.resolve('zod'));
  for (const extension of ['js', 'cjs']) {
    assert.match(
      readFileSync(path.join(directory, `v3/helpers/parseUtil.${extension}`), 'utf8'),
      /ctx.common.issues.length >= 1000/,
    );
  }
});

test('the backend uses upstream-fixed Zod 4 rather than the compatibility exception', () => {
  const version = JSON.parse(
    readFileSync(path.resolve(__dirname, '../../backend/node_modules/zod/package.json'), 'utf8'),
  ).version as string;
  const [major, minor, patch] = version.split('.').map(Number);
  assert.ok(major === 4 && (minor! > 6 || (minor === 6 && patch! >= 6)));
});
