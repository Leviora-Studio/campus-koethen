// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  CorsConfigurationError,
  DEVELOPMENT_ORIGIN,
  corsOrigins,
} from '../src/security/cors-origins';

test('uses the environment allowlist verbatim', () => {
  assert.deepEqual(
    corsOrigins({
      allowlist: 'https://cms.example.org, https://admin.example.org',
      production: true,
    }),
    ['https://cms.example.org', 'https://admin.example.org'],
  );
});

test('ignores empty entries and surrounding whitespace', () => {
  assert.deepEqual(corsOrigins({ allowlist: ' https://a.example.org ,, ', production: true }), [
    'https://a.example.org',
  ]);
});

// The whole reason this function exists: Strapi's default reflects the caller's
// Origin, which is the one thing a production CMS must never do.
test('refuses a wildcard in production', () => {
  assert.throws(
    () => corsOrigins({ allowlist: 'https://a.example.org,*', production: true }),
    CorsConfigurationError,
  );
});

test('allows a wildcard outside production, where it is a local convenience', () => {
  assert.deepEqual(corsOrigins({ allowlist: '*', production: false }), ['*']);
});

test('falls back to the CMS public origin, not to a wildcard', () => {
  assert.deepEqual(corsOrigins({ publicUrl: 'https://cms.example.org/admin', production: true }), [
    'https://cms.example.org',
  ]);
});

test('drops a public URL that is not an http(s) origin', () => {
  assert.deepEqual(corsOrigins({ publicUrl: 'not a url', production: true }), []);
  assert.deepEqual(corsOrigins({ publicUrl: 'file:///tmp', production: false }), [
    DEVELOPMENT_ORIGIN,
  ]);
});

// An empty list is what Strapi needs in order to allow nobody. Falling back to
// a localhost origin in production, or to a wildcard, would both be worse.
test('allows nobody in production when nothing is configured', () => {
  assert.deepEqual(corsOrigins({ production: true }), []);
  assert.deepEqual(corsOrigins({ allowlist: '   ', production: true }), []);
});

// The build loads this file with NODE_ENV=production and placeholders only, so
// a missing setting must never be able to fail it.
test('never throws for a merely absent configuration', () => {
  assert.doesNotThrow(() => corsOrigins({ production: true }));
  assert.doesNotThrow(() => corsOrigins({ production: false }));
});

test('uses the documented local default in development', () => {
  assert.deepEqual(corsOrigins({ production: false }), [DEVELOPMENT_ORIGIN]);
});
