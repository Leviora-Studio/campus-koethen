// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

/**
 * G5 without a runtime check — and why that is now the stronger position.
 *
 * G5 says the Strapi Public Role gets no general public read rights. It used to
 * be checked at boot by `src/bootstrap/public-role-guard.ts`, which queried
 * `plugin::users-permissions.role`. That plugin was removed from the CMS, so
 * the query resolved to nothing and the guard logged
 * `could not verify the G5 lockdown` on every start: a check that read as
 * active while verifying nothing at all.
 *
 * Removing the plugin does not weaken G5, it settles it. Without
 * `users-permissions` there is no public role, no permission table and nothing
 * an admin could tick by accident; every `/api/*` route answers `401 Missing or
 * invalid credentials`, and the Campus API's own read-only API token — served
 * by Strapi core, not by this plugin — is the only way in.
 *
 * That guarantee rests entirely on the plugin staying absent. Re-adding it
 * recreates a public role whose rights live in the database where CI cannot see
 * them, and G5 would need a runtime check again. This test is the tripwire for
 * exactly that moment: it is cheap, it runs in CI, and it fails on the commit
 * that reintroduces the dependency rather than months later.
 */
const PLUGIN = '@strapi/plugin-users-permissions';

test('the users-permissions plugin stays absent, so no public role can exist', () => {
  const manifest = JSON.parse(readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8')) as {
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
  };

  const declared = {
    ...(manifest.dependencies ?? {}),
    ...(manifest.devDependencies ?? {}),
  };

  assert.equal(
    PLUGIN in declared,
    false,
    `${PLUGIN} is back in apps/cms/package.json. That recreates the Strapi Public Role, ` +
      'whose content permissions live in the database and are invisible to CI. G5 then needs a ' +
      'runtime check again (see git history for src/bootstrap/public-role-guard.ts) — restore ' +
      'one before deleting this test.',
  );
});
