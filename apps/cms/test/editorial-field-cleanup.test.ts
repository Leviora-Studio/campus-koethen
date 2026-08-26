import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import cmsPackage from '../package.json';
import contactArea from '../src/api/contact-area/content-types/contact-area/schema.json';
import post from '../src/api/post/content-types/post/schema.json';
import publicCalendar from '../src/api/public-calendar/content-types/public-calendar/schema.json';

test('public calendar keeps only understandable event inclusion switches', () => {
  const attributes = publicCalendar.attributes as Record<string, unknown>;
  for (const removed of ['description', 'iconKey', 'ownerContact', 'attribution', 'timeZone']) {
    assert.equal(removed in attributes, false);
  }
  assert.equal('showDescription' in attributes, false);
  assert.equal('showLocation' in attributes, false);
  assert.equal('includeEventDescription' in attributes, true);
  assert.equal('includeEventLocation' in attributes, true);
});

test('contact area icon is a bounded dropdown and obsolete demo state is gone', () => {
  const attributes = contactArea.attributes as Record<string, unknown>;
  const icon = attributes.iconKey as { type: string; enum: string[]; default: string };

  assert.equal(icon.type, 'enumeration');
  assert.equal(icon.default, 'service');
  assert.ok(icon.enum.includes('students-council'));
  assert.ok(icon.enum.includes('library'));
  assert.equal('isDemoContent' in attributes, false);
  assert.equal('appointmentUrl' in attributes, false);
  assert.equal('appointmentBookingUrl' in attributes, true);
});

test('author and public user collection types are completely removed', () => {
  const postAttributes = post.attributes as Record<string, unknown>;
  const authorSchema = resolve(__dirname, '../src/api/author/content-types/author/schema.json');
  const pluginConfig = readFileSync(resolve(__dirname, '../config/plugins.ts'), 'utf8');

  assert.equal('authors' in postAttributes, false);
  assert.equal(existsSync(authorSchema), false);
  assert.equal('@strapi/plugin-users-permissions' in cmsPackage.dependencies, false);
  assert.doesNotMatch(pluginConfig, /users-permissions/);
});
