// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

/**
 * Mirrors the CI gate in `.github/workflows/ci.yml`: every slug is the stable
 * cross-locale id, so it is unique and says `i18n.localized = false` on the
 * field itself — also on content types that have no language versions at all,
 * because the gate reads only the field.
 */
const api = join(__dirname, '..', 'src', 'api');

const schemas = readdirSync(api).flatMap((name) => {
  const contentTypes = join(api, name, 'content-types');
  try {
    return readdirSync(contentTypes).map((type) => join(contentTypes, type, 'schema.json'));
  } catch {
    return [];
  }
});

test('the content-type scan finds the schemas', () => {
  assert.ok(schemas.length >= 9, `found only ${schemas.length} schemas`);
});

for (const file of schemas) {
  const schema = JSON.parse(readFileSync(file, 'utf8')) as {
    info: { singularName: string };
    attributes: Record<
      string,
      { unique?: boolean; pluginOptions?: { i18n?: { localized?: boolean } } }
    >;
  };
  const slug = schema.attributes['slug'];
  if (!slug) continue;

  test(`${schema.info.singularName}: slug is unique and explicitly not localised`, () => {
    assert.equal(slug.unique, true);
    assert.equal(slug.pluginOptions?.i18n?.localized, false);
  });
}
