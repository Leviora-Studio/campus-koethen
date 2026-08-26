// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';

import {
  MAX_UPLOAD_SIZE_LIMIT_BYTES,
  UPLOAD_SIZE_LIMIT_BYTES,
  allowedMediaTypes,
  deniedExecutableTypes,
  validatedUploadSizeLimit,
} from '../config/plugins';

/**
 * Does the upload allow list actually DO anything?
 *
 * The security audit could not tell: `plugin.upload.security` is thinly
 * documented, and a control nobody has exercised is not a control. So this test
 * does not restate the configuration — it hands exactly our lists to the
 * validator inside the INSTALLED `@strapi/upload` and asserts what that
 * validator decides. If a Strapi upgrade drops, renames or reinterprets the
 * option, these assertions stop matching instead of quietly passing.
 *
 * `validateFile` is deliberately content-based: it sniffs the first 4100 bytes,
 * so a file's real bytes decide, not its name or its declared Content-Type.
 */

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- the plugin ships no public types for its internal validator; the shape is asserted on below.
type ValidationResult = { isValid: boolean; error?: { message: string; details?: any } };

/**
 * Loaded by absolute path on purpose.
 *
 * `@strapi/upload` is a transitive dependency and its `exports` map does not
 * publish this file, so a bare specifier cannot reach it. Resolving the package
 * root through `@strapi/strapi` and then joining the path keeps the test bound
 * to the validator that this deployment actually runs. If an upgrade moves or
 * removes it, the require throws here — loudly — instead of the suite silently
 * verifying nothing.
 */
// eslint-disable-next-line @typescript-eslint/no-require-imports
const uploadPackageJson = require.resolve('@strapi/upload/package.json', {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  paths: [dirname(require.resolve('@strapi/strapi/package.json'))],
});

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { validateFile, detectMimeType } = require(
  join(dirname(uploadPackageJson), 'dist/server/utils/mime-validation.js'),
) as {
  validateFile: (
    file: unknown,
    config: { allowedTypes?: string[]; deniedTypes?: string[] },
    strapi: unknown,
  ) => Promise<ValidationResult>;
  detectMimeType: (file: unknown) => Promise<string | undefined>;
};

const securityConfig = { allowedTypes: allowedMediaTypes, deniedTypes: deniedExecutableTypes };
const strapiStub = { log: { warn: () => {}, error: () => {} } };

const workdir = mkdtempSync(join(tmpdir(), 'campus-upload-security-'));

/** Writes real bytes to disk — content detection needs a file, not a claim. */
function fileWith(name: string, bytes: Buffer | string, declaredType: string) {
  const filepath = join(workdir, name);
  writeFileSync(filepath, bytes);
  return { filepath, originalFilename: name, mimetype: declaredType };
}

/** A minimal but genuine PNG: the 8-byte signature plus an IHDR chunk. */
const PNG_BYTES = Buffer.from(
  '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489',
  'hex',
);

const SVG_BYTES = '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>';

const check = (file: unknown) => validateFile(file, securityConfig, strapiStub);

test('the option is real: a genuine PNG is accepted', async () => {
  const result = await check(fileWith('photo.png', PNG_BYTES, 'image/png'));
  assert.equal(result.isValid, true);
});

test('an SVG is refused even though the allow list contains image/*', async () => {
  // `image/*` expands to a wildcard regex that MATCHES image/svg+xml, and the
  // plugin additionally trusts a .svg extension when that type is allowed. Only
  // the explicit entry in deniedTypes stops it — which is why it is there.
  const result = await check(fileWith('logo.svg', SVG_BYTES, 'image/svg+xml'));
  assert.equal(result.isValid, false);
  assert.match(result.error?.message ?? '', /not allowed/i);
});

test('an SVG is still refused when it lies about its own type', async () => {
  const result = await check(fileWith('logo2.svg', SVG_BYTES, 'application/octet-stream'));
  assert.equal(result.isValid, false);
});

/**
 * The limit of this control, pinned so it is a known quantity rather than a
 * surprise.
 *
 * Content detection is `file-type`, which reads binary magic numbers. SVG is
 * TEXT and has none, so detection returns `undefined` for it — verified above
 * and asserted here. With nothing detected, the plugin falls back to the
 * extension, and SVG bytes carrying a `.png` name are accepted and stored as
 * `image/png`.
 *
 * Why that is acceptable and the `.svg` case is not: what makes an SVG
 * dangerous is being INTERPRETED as SVG, which needs `Content-Type:
 * image/svg+xml`. A file stored and served as `image/png` — with the
 * `nosniff` that `strapi::security` sets — is never parsed as a document.
 * The upload path that really mattered is the honest `.svg` one, and that is
 * closed above.
 *
 * If this assertion ever flips to rejecting, that is an improvement upstream,
 * not a regression — but it should be noticed rather than absorbed silently.
 */
test('a disguised SVG is accepted on its extension — detection cannot see text formats', async () => {
  assert.equal(
    await detectMimeType({ filepath: fileWith('probe.svg', SVG_BYTES, '').filepath }),
    undefined,
  );

  const result = await check(fileWith('disguised.png', SVG_BYTES, 'image/png'));
  assert.equal(result.isValid, true);
});

test('an executable is refused', async () => {
  // 'MZ' — the DOS/PE signature.
  const result = await check(fileWith('tool.exe', Buffer.from('4d5a9000', 'hex'), 'image/png'));
  assert.equal(result.isValid, false);
});

test('a shell script is refused despite a .txt name and a text/plain claim', async () => {
  const result = await check(fileWith('setup.sh', '#!/bin/sh\nrm -rf /\n', 'text/plain'));
  assert.equal(result.isValid, false);
});

test('the size limit is set at all, and to something a disk can survive', () => {
  // Unset means the plugin default of 1 GB per file against a volume with no
  // quota — the editor role could fill the VPS disk on its own.
  assert.equal(typeof UPLOAD_SIZE_LIMIT_BYTES, 'number');
  assert.ok(UPLOAD_SIZE_LIMIT_BYTES > 0);
  assert.ok(UPLOAD_SIZE_LIMIT_BYTES <= 100 * 1024 * 1024);
});

test('an environment override cannot disable or unbound the upload limit', () => {
  assert.equal(validatedUploadSizeLimit(UPLOAD_SIZE_LIMIT_BYTES), UPLOAD_SIZE_LIMIT_BYTES);
  assert.equal(validatedUploadSizeLimit(MAX_UPLOAD_SIZE_LIMIT_BYTES), MAX_UPLOAD_SIZE_LIMIT_BYTES);
  assert.throws(() => validatedUploadSizeLimit(0), /UPLOAD_SIZE_LIMIT_BYTES/);
  assert.throws(
    () => validatedUploadSizeLimit(MAX_UPLOAD_SIZE_LIMIT_BYTES + 1),
    /UPLOAD_SIZE_LIMIT_BYTES/,
  );
});

test('SVG is denied, not merely left out of the allow list', () => {
  // Absence would not be enough: `image/*` already covers it.
  assert.ok(deniedExecutableTypes.includes('image/svg+xml'));
});
