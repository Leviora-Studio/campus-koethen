// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import tagSchema from '../src/api/tag/content-types/tag/schema.json';
import postSchema from '../src/api/post/content-types/post/schema.json';

test('tag <-> post is a manyToOne relation from post to tag, oneToMany from tag to post', () => {
  const tagAttr = postSchema.attributes.tag as {
    relation: string;
    target: string;
    inversedBy: string;
    required: boolean;
    pluginOptions: { i18n: { localized: boolean } };
  };
  const postsAttr = tagSchema.attributes.posts as {
    relation: string;
    target: string;
    mappedBy: string;
  };

  assert.equal(tagAttr.relation, 'manyToOne');
  assert.equal(tagAttr.target, 'api::tag.tag');
  assert.equal(tagAttr.inversedBy, 'posts');
  assert.equal(tagAttr.required, true);
  assert.equal(tagAttr.pluginOptions.i18n.localized, false, 'tag relation must be non-localised');

  assert.equal(postsAttr.relation, 'oneToMany');
  assert.equal(postsAttr.target, 'api::post.post');
  assert.equal(postsAttr.mappedBy, 'tag');
});

test('post primaryChannel is a manyToOne relation and channels is manyToMany', () => {
  const primaryChannel = postSchema.attributes.primaryChannel as {
    relation: string;
    target: string;
    required: boolean;
    pluginOptions: { i18n: { localized: boolean } };
  };
  const channels = postSchema.attributes.channels as {
    relation: string;
    target: string;
    inversedBy: string;
    pluginOptions: { i18n: { localized: boolean } };
  };

  assert.equal(primaryChannel.relation, 'manyToOne');
  assert.equal(primaryChannel.target, 'api::channel.channel');
  assert.equal(primaryChannel.required, true);
  assert.equal(primaryChannel.pluginOptions.i18n.localized, false);

  assert.equal(channels.relation, 'manyToMany');
  assert.equal(channels.target, 'api::channel.channel');
  assert.equal(channels.inversedBy, 'posts');
  assert.equal(channels.pluginOptions.i18n.localized, false);
});

test('post defines only the required event time fields', () => {
  const eventStart = postSchema.attributes.eventStart as {
    type: string;
    pluginOptions: { i18n: { localized: boolean } };
  };
  const eventEnd = postSchema.attributes.eventEnd as {
    type: string;
    pluginOptions: { i18n: { localized: boolean } };
  };
  const eventAllDay = postSchema.attributes.eventAllDay as {
    type: string;
    default: boolean;
    pluginOptions: { i18n: { localized: boolean } };
  };

  assert.equal(eventStart.type, 'datetime');
  assert.equal(eventStart.pluginOptions.i18n.localized, false);

  assert.equal(eventEnd.type, 'datetime');
  assert.equal(eventEnd.pluginOptions.i18n.localized, false);

  assert.equal(eventAllDay.type, 'boolean');
  assert.equal(eventAllDay.default, false);
  assert.equal(eventAllDay.pluginOptions.i18n.localized, false);

  assert.equal('eventTimeZone' in postSchema.attributes, false);
});

test('tag has a required, unique, slug-shaped slug and defaults to active', () => {
  const slug = tagSchema.attributes.slug as {
    required: boolean;
    unique: boolean;
    regex: string;
  };
  const isActive = tagSchema.attributes.isActive as { type: string; default: boolean };

  assert.equal(slug.required, true);
  assert.equal(slug.unique, true);
  assert.match('news', new RegExp(slug.regex));
  assert.match('event', new RegExp(slug.regex));
  assert.doesNotMatch('Not A Slug!', new RegExp(slug.regex));

  assert.equal(isActive.type, 'boolean');
  assert.equal(isActive.default, true);
});

test('tag stores only name, slug, active state and its post relation', () => {
  const name = tagSchema.attributes.name as { pluginOptions: { i18n: { localized: boolean } } };
  const slug = tagSchema.attributes.slug as { pluginOptions: { i18n: { localized: boolean } } };

  assert.equal(name.pluginOptions.i18n.localized, true);
  assert.equal(
    slug.pluginOptions.i18n.localized,
    false,
    'slug must stay the stable cross-locale id',
  );
  assert.deepEqual(Object.keys(tagSchema.attributes), ['name', 'slug', 'isActive', 'posts']);
});

test('post has no teaser or pinned state', () => {
  assert.equal('teaser' in postSchema.attributes, false);
  assert.equal('isPinned' in postSchema.attributes, false);
});
