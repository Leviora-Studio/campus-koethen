// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { mapChannel, mapPostDetail, mapPostListItem, mapTag } from './posts.mapper';

describe('posts mappers', () => {
  describe('mapChannel', () => {
    const raw = {
      id: 1,
      documentId: 'doc_abc',
      name: 'Campus News',
      slug: 'campus-news',
      description: 'Rund um den Campus.',
      colorHex: '#5B3FD0',
      sortOrder: 10,
      isActive: true,
      defaultSubscribed: true,
      publicCalendar: { id: 10, documentId: 'cal_1', slug: 'campus-calendar' },
      locale: 'de',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-02T00:00:00.000Z',
      publishedAt: '2026-01-02T00:00:00.000Z',
      localizations: [{ id: 2, documentId: 'doc_abc', locale: 'en' }],
    };

    it('maps the public fields including publicCalendarSlug', () => {
      expect(mapChannel(raw)).toEqual({
        slug: 'campus-news',
        name: 'Campus News',
        description: 'Rund um den Campus.',
        colorHex: '#5B3FD0',
        sortOrder: 10,
        defaultSubscribed: true,
        publicCalendarSlug: 'campus-calendar',
      });
    });

    it('never leaks Strapi internals', () => {
      const serialized = JSON.stringify(mapChannel(raw));
      for (const leak of ['documentId', 'localizations', 'createdAt', 'updatedAt', 'publishedAt']) {
        expect(serialized).not.toContain(leak);
      }
      expect(mapChannel(raw)).not.toHaveProperty('id');
      expect(mapChannel(raw)).not.toHaveProperty('isActive');
    });

    it('normalises a missing description to null and missing publicCalendar to null', () => {
      expect(mapChannel({ ...raw, description: undefined, publicCalendar: null })).toEqual({
        slug: 'campus-news',
        name: 'Campus News',
        description: null,
        colorHex: '#5B3FD0',
        sortOrder: 10,
        defaultSubscribed: true,
        publicCalendarSlug: null,
      });
    });
  });

  describe('mapTag', () => {
    const raw = {
      id: 1,
      documentId: 'doc_tag',
      name: 'Event',
      slug: 'event',
      description: 'Veranstaltungen und Termine.',
      iconKey: 'event',
      colorHex: '#E85D75',
      sortOrder: 20,
      isActive: true,
      locale: 'de',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-02T00:00:00.000Z',
      publishedAt: '2026-01-02T00:00:00.000Z',
      localizations: [{ id: 2, documentId: 'doc_tag', locale: 'en' }],
    };

    it('maps the public fields', () => {
      expect(mapTag(raw)).toEqual({
        slug: 'event',
        name: 'Event',
      });
    });

    it('never leaks Strapi internals', () => {
      const serialized = JSON.stringify(mapTag(raw));
      for (const leak of ['documentId', 'localizations', 'createdAt', 'updatedAt', 'publishedAt']) {
        expect(serialized).not.toContain(leak);
      }
      expect(mapTag(raw)).not.toHaveProperty('id');
      expect(mapTag(raw)).not.toHaveProperty('isActive');
    });

    it('drops obsolete presentation fields', () => {
      expect(mapTag(raw)).not.toHaveProperty('description');
      expect(mapTag(raw)).not.toHaveProperty('iconKey');
      expect(mapTag(raw)).not.toHaveProperty('colorHex');
      expect(mapTag(raw)).not.toHaveProperty('sortOrder');
    });
  });

  describe('mapPostListItem', () => {
    const raw = {
      id: 5,
      documentId: 'doc_post',
      title: 'Semesterstart',
      slug: 'semesterstart-2026',
      publishedAt: '2026-07-20T09:00:00.000Z',
      sourceName: 'Hochschule Anhalt',
      sourceUrl: 'https://www.hs-anhalt.de/news',
      heroImage: {
        id: 9,
        documentId: 'doc_img',
        url: '/uploads/hero_abc123.jpg',
        alternativeText: 'Ein Bild',
        width: 1600,
        height: 900,
      },
      tag: {
        id: 7,
        documentId: 't1',
        slug: 'event',
        name: 'Event',
        iconKey: 'event',
        colorHex: '#E85D75',
      },
      primaryChannel: {
        id: 1,
        documentId: 'c1',
        slug: 'campus-news',
        name: 'Campus News',
        colorHex: '#5B3FD0',
      },
      channels: [
        { id: 1, documentId: 'c1', slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
        { id: 2, documentId: 'c2', slug: 'fb5-news', name: 'FB5 News', colorHex: '#E8B44F' },
      ],
      eventStart: '2026-10-01T08:00:00.000Z',
      eventEnd: '2026-10-01T12:00:00.000Z',
      eventAllDay: false,
    };

    it('maps the public listing shape with tag, primaryChannel and event fields', () => {
      const result = mapPostListItem(raw).item;
      expect(result).toEqual({
        slug: 'semesterstart-2026',
        title: 'Semesterstart',
        publishedAt: '2026-07-20T09:00:00.000Z',
        heroImage: {
          url: '/v1/media/uploads/hero_abc123.jpg',
          alternativeText: 'Ein Bild',
          width: 1600,
          height: 900,
        },
        tag: { slug: 'event', name: 'Event' },
        primaryChannel: { slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
        channels: [
          { slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
          { slug: 'fb5-news', name: 'FB5 News', colorHex: '#E8B44F' },
        ],
        sourceName: 'Hochschule Anhalt',
        sourceUrl: 'https://www.hs-anhalt.de/news',
        content: [],
        eventStart: '2026-10-01T08:00:00.000Z',
        eventEnd: '2026-10-01T12:00:00.000Z',
        eventAllDay: false,
      });
    });

    it('returns item: null when tag or primaryChannel is missing', () => {
      expect(mapPostListItem({ ...raw, tag: null }).item).toBeNull();
      expect(mapPostListItem({ ...raw, primaryChannel: null }).item).toBeNull();
    });

    it('ensures primaryChannel is in channels list', () => {
      const result = mapPostListItem({
        ...raw,
        channels: [{ slug: 'fb5-news', name: 'FB5 News', colorHex: '#E8B44F' }],
      }).item;
      expect(result?.channels.map((c) => c.slug)).toEqual(['campus-news', 'fb5-news']);
    });

    it('drops non-https sourceUrl', () => {
      expect(
        mapPostListItem({ ...raw, sourceUrl: 'http://insecure.example' }).item?.sourceUrl,
      ).toBeNull();
    });

    it('drops non-upload heroImage', () => {
      expect(
        mapPostListItem({ ...raw, heroImage: { url: 'https://cdn.example/outside.jpg' } }).item
          ?.heroImage,
      ).toBeNull();
    });
  });

  describe('mapPostDetail', () => {
    it('returns post detail with content and droppedBlockTypes', () => {
      const raw = {
        title: 'T',
        slug: 's',
        publishedAt: '2026-07-20T09:00:00.000Z',
        tag: { slug: 'news', name: 'News', iconKey: 'news', colorHex: '#3E7BFA' },
        primaryChannel: { slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
        content: [
          { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
          { type: 'future-embed', payload: 1 },
        ],
      };

      const result = mapPostDetail(raw);
      expect(result.post?.content).toEqual([
        { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
      ]);
      expect(result.droppedBlockTypes).toEqual(['future-embed']);
    });
  });
});
