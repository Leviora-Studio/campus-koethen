// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { SvgParseError, findRooms, findUnsafe, parseSvgDocument } from '../src/svg-reader.mjs';

const MINIMAL = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">
  <g id="floor-plan">
    <rect id="room-a" class="room office" x="1" y="2" width="3" height="4"
      data-room-key="a" data-room-number="A.1"
      data-building-key="b" data-floor-key="f"
      data-focus-x="2" data-focus-y="4" />
  </g>
</svg>`;

test('parses a well-formed document into a lossless tree', () => {
  const root = parseSvgDocument(MINIMAL);
  assert.equal(root.name, 'svg');
  assert.equal(root.attrs.viewBox, '0 0 100 50');

  // The tree keeps whitespace text nodes so a document can be re-serialised
  // faithfully; only element children are asserted here.
  const elements = root.children.filter((child) => child.type === 'element');
  assert.equal(elements.length, 1);
  assert.equal(elements[0].name, 'g');
  assert.ok(root.children.some((child) => child.type === 'text'));
});

test('finds room elements with their attributes', () => {
  const rooms = findRooms(parseSvgDocument(MINIMAL));
  assert.equal(rooms.length, 1);
  assert.equal(rooms[0].attrs['data-room-key'], 'a');
  assert.equal(rooms[0].attrs.id, 'room-a');
});

test('decodes the five standard entities in attribute values', () => {
  const root = parseSvgDocument(
    `<svg xmlns="http://www.w3.org/2000/svg"><desc id="a &amp; b"></desc></svg>`,
  );
  assert.equal(root.children[0].attrs.id, 'a & b');
});

test('rejects a DOCTYPE, which is the entity-expansion attack surface', () => {
  assert.throws(
    () => parseSvgDocument(`<!DOCTYPE svg [<!ENTITY x "y">]><svg xmlns="x"/>`),
    SvgParseError,
  );
});

test('rejects unbalanced tags rather than guessing', () => {
  assert.throws(
    () => parseSvgDocument(`<svg xmlns="http://www.w3.org/2000/svg"><g></svg>`),
    SvgParseError,
  );
});

test('rejects CDATA sections', () => {
  assert.throws(
    () => parseSvgDocument(`<svg xmlns="http://www.w3.org/2000/svg"><![CDATA[x]]></svg>`),
    SvgParseError,
  );
});

test('rejects a non-svg root element', () => {
  assert.throws(() => parseSvgDocument(`<html></html>`), SvgParseError);
});

for (const [label, markup] of [
  ['script elements', `<script>alert(1)</script>`],
  ['foreignObject', `<foreignObject width="1" height="1"></foreignObject>`],
  ['embedded raster images', `<image href="data:image/png;base64,AAA" />`],
  ['external hrefs', `<a href="https://example.com/x"><rect /></a>`],
  ['xlink hrefs', `<use xlink:href="https://example.com/x" />`],
  ['external url() references', `<rect fill="url(https://example.com/p)" />`],
  ['event handlers', `<rect onload="alert(1)" />`],
  ['javascript: urls', `<a href="javascript:alert(1)"></a>`],
]) {
  test(`flags ${label} as unsafe`, () => {
    const root = parseSvgDocument(`<svg xmlns="http://www.w3.org/2000/svg">${markup}</svg>`);
    assert.ok(findUnsafe(root).length > 0, `expected ${label} to be reported`);
  });
}

test('accepts local url() references such as gradients and clip paths', () => {
  const root = parseSvgDocument(
    `<svg xmlns="http://www.w3.org/2000/svg"><rect fill="url(#grad)" /></svg>`,
  );
  assert.deepEqual(findUnsafe(root), []);
});

test('reports nothing unsafe for the minimal document', () => {
  assert.deepEqual(findUnsafe(parseSvgDocument(MINIMAL)), []);
});
