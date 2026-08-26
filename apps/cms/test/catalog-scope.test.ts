// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/**
 * The scope has to survive DUPLICATE MODULE INSTANCES.
 *
 * Strapi boots the application from `dist/`, while `rooms:sync` imports the
 * same files from `src/` through ts-node. Both copies are loaded into one
 * process, so a plain module-level AsyncLocalStorage gives each copy its OWN
 * instance: the scope opened by the sync is then invisible to the guard, and
 * the guard rejects the very writes it is supposed to allow.
 *
 * That is not hypothetical — it is exactly what happened the first time the
 * sync ran against a real Strapi. These tests reproduce it by forcing a second
 * module instance through the require cache.
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isCatalogSync, runAsCatalogSync } from '../src/catalog/catalog-scope';

type ScopeModule = typeof import('../src/catalog/catalog-scope');

/** Loads a genuinely separate instance of the module. */
function loadSecondInstance(): ScopeModule {
  const resolved = require.resolve('../src/catalog/catalog-scope');
  delete require.cache[resolved];
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const second = require('../src/catalog/catalog-scope') as ScopeModule;
  // Restore the first instance so the rest of the suite keeps using it.
  delete require.cache[resolved];
  return second;
}

test('a second module instance sees the scope opened by the first', async () => {
  const second = loadSecondInstance();

  assert.equal(second.isCatalogSync(), false, 'must start outside the scope');

  await runAsCatalogSync(async () => {
    assert.equal(isCatalogSync(), true, 'the opening instance sees its own scope');
    assert.equal(
      second.isCatalogSync(),
      true,
      'a duplicate module instance must see the SAME scope — otherwise the ' +
        'guard rejects the sync it is meant to permit',
    );
  });
});

test('the scope still closes for every instance', async () => {
  const second = loadSecondInstance();
  await runAsCatalogSync(async () => 'done');

  assert.equal(isCatalogSync(), false);
  assert.equal(second.isCatalogSync(), false);
});

test('the scope does not leak into unrelated async work', async () => {
  let insideParallelTask: boolean | null = null;

  const parallel = new Promise<void>((resolve) => {
    setTimeout(() => {
      insideParallelTask = isCatalogSync();
      resolve();
    }, 0);
  });

  await runAsCatalogSync(async () => {
    assert.equal(isCatalogSync(), true);
  });
  await parallel;

  assert.equal(insideParallelTask, false, 'work started outside must stay outside');
});
