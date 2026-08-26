#!/usr/bin/env node
/**
 * Structural check of the published OpenAPI contract.
 *
 * This is intentionally dependency-free. It does not try to be a full OpenAPI
 * validator — it asserts the guarantees this project actually makes, so a
 * regression in the contract fails CI rather than reaching a client.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const documentPath = join(here, '..', 'openapi.json');

/** Endpoints the mobile client depends on. */
const REQUIRED_PATHS = [
  '/health/live',
  '/health/ready',
  '/v1/posts/channels',
  '/v1/posts/tags',
  '/v1/posts/events',
  '/v1/posts',
  '/v1/posts/{slug}',
  '/v1/contact-areas',
  '/v1/contact-areas/{slug}',
  '/v1/canteens',
  '/v1/canteens/{slug}/menu',
  '/v1/rooms',
  '/v1/rooms/{roomKey}',
  '/v1/calendars',
  '/v1/calendars/events',
  '/v1/calendars/{slug}/events',
  '/v1/calendars/google-view-url',
];

/**
 * Content endpoints answer with the `{ data, meta }` envelope from docs/api.md
 * §1. `/health/*` is the documented exception: a liveness probe is not content.
 *
 * This check exists because the calendar endpoints once documented a bare
 * array while actually returning the envelope — the generated contract said one
 * thing, the running server another, and nothing caught it.
 */
const ENVELOPE_EXEMPT_PATHS = ['/health/live', '/health/ready', '/v1/media/uploads/{filename}'];

/**
 * Strapi internals that must never appear anywhere in the contract.
 * `attributes` is excluded from this list on purpose: it is a legitimate word
 * in prose, so it is checked structurally instead (see below).
 */
const FORBIDDEN_TOKENS = ['documentId', 'populate', 'localizations', 'image_url', 'location_id'];

const problems = [];

let document;
try {
  document = JSON.parse(readFileSync(documentPath, 'utf8'));
} catch (error) {
  console.error(
    `Cannot read ${documentPath}. Run "pnpm openapi:generate" first.\n${error.message}`,
  );
  process.exit(1);
}

if (document.info?.license?.name !== 'AGPL-3.0-only') {
  problems.push(`info.license.name must be "AGPL-3.0-only", got "${document.info?.license?.name}"`);
}

for (const path of REQUIRED_PATHS) {
  if (!document.paths?.[path]) {
    problems.push(`missing required path: ${path}`);
  }
}

// The API is read-only; any mutating verb would be a contract change.
for (const [path, operations] of Object.entries(document.paths ?? {})) {
  for (const method of Object.keys(operations)) {
    if (!['get', 'parameters'].includes(method)) {
      problems.push(`unexpected non-GET operation: ${method.toUpperCase()} ${path}`);
    }
  }
}

/**
 * Leak check.
 *
 * Deliberately structural rather than a substring sweep over the whole
 * document: descriptions legitimately mention these names to state that they
 * are NOT exposed (e.g. "the upstream location_id is never exposed"). Only
 * actual identifiers — schema properties, parameter names and path segments —
 * would constitute a real leak.
 */
function checkIdentifier(identifier, where) {
  for (const token of FORBIDDEN_TOKENS) {
    if (identifier === token || identifier.toLowerCase() === token.toLowerCase()) {
      problems.push(`contract leaks an internal identifier "${token}" as ${where}`);
    }
  }
}

for (const [name, schema] of Object.entries(document.components?.schemas ?? {})) {
  const properties = Object.keys(schema.properties ?? {});
  for (const property of properties) {
    checkIdentifier(property, `a property of schema "${name}"`);
  }
  // A raw Strapi envelope would carry both of these together.
  if (properties.includes('attributes') && properties.includes('data')) {
    problems.push(`schema "${name}" looks like a raw Strapi envelope (data + attributes)`);
  }
}

/** Resolves a local `$ref` to the schema it names. Non-refs pass through. */
function resolveSchema(schema) {
  const ref = schema?.$ref;
  if (typeof ref !== 'string') return schema;
  const name = ref.replace('#/components/schemas/', '');
  return document.components?.schemas?.[name];
}

for (const [path, operations] of Object.entries(document.paths ?? {})) {
  if (ENVELOPE_EXEMPT_PATHS.includes(path)) continue;
  const schema = operations.get?.responses?.['200']?.content?.['application/json']?.schema;
  if (!schema) {
    problems.push(`GET ${path} documents no application/json 200 response schema`);
    continue;
  }
  const resolved = resolveSchema(schema);
  const properties = Object.keys(resolved?.properties ?? {});
  if (!properties.includes('data') || !properties.includes('meta')) {
    problems.push(
      `GET ${path} must document the { data, meta } envelope, got ` +
        `${schema.$ref ?? JSON.stringify(schema.type ?? schema)}`,
    );
  }
}

/**
 * A property typed as a bare `object` with neither `properties` nor a `$ref`
 * carries no information at all — it is what `@ApiPropertyOptional({ nullable:
 * true })` produces when the `type` is left off, and it silently turned four
 * plain strings into untyped objects.
 */
for (const [name, schema] of Object.entries(document.components?.schemas ?? {})) {
  for (const [property, definition] of Object.entries(schema.properties ?? {})) {
    const isOpaqueObject =
      definition?.type === 'object' &&
      !definition.properties &&
      !definition.additionalProperties &&
      !definition.allOf &&
      !definition.$ref;
    if (isOpaqueObject) {
      problems.push(
        `${name}.${property} is documented as an untyped object — add an explicit ` +
          `\`type\` to its @ApiProperty decorator`,
      );
    }
  }
}

for (const [path, operations] of Object.entries(document.paths ?? {})) {
  for (const segment of path.split('/')) {
    checkIdentifier(segment.replace(/[{}]/g, ''), `a path segment of ${path}`);
  }
  for (const operation of Object.values(operations)) {
    for (const parameter of operation.parameters ?? []) {
      checkIdentifier(parameter.name ?? '', `a query/path parameter of ${path}`);
    }
  }
}

if (problems.length > 0) {
  console.error('OpenAPI contract validation FAILED:');
  for (const problem of problems) {
    console.error(`  - ${problem}`);
  }
  process.exit(1);
}

console.log(
  `OpenAPI contract OK: ${Object.keys(document.paths).length} paths, read-only, no upstream identifiers leaked.`,
);
