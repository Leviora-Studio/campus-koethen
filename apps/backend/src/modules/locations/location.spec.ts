// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiError } from '../../common/errors/api-error';
import { filterByLocation, mapLocationRef, parseLocationFilter } from './location';

describe('location reference', () => {
  const raw = {
    id: 3,
    documentId: 'loc_doc',
    slug: 'demo-ort',
    name: 'Demo-Ort',
    isActive: true,
    createdAt: '2026-11-21T00:00:00.000Z',
  };

  it('maps an active location to slug and name only', () => {
    expect(mapLocationRef(raw)).toEqual({ slug: 'demo-ort', name: 'Demo-Ort' });
  });

  it('serves no location for missing, inactive or malformed relations', () => {
    expect(mapLocationRef(null)).toBeNull();
    expect(mapLocationRef(undefined)).toBeNull();
    expect(mapLocationRef([raw])).toBeNull();
    expect(mapLocationRef({ ...raw, isActive: false })).toBeNull();
    expect(mapLocationRef({ ...raw, slug: 'Not A Slug' })).toBeNull();
    expect(mapLocationRef({ ...raw, name: '' })).toBeNull();
  });

  it('treats a location without isActive as active', () => {
    // A populate that asked only for slug and name must not hide the location.
    expect(mapLocationRef({ slug: 'demo-ort', name: 'Demo-Ort' })).toEqual({
      slug: 'demo-ort',
      name: 'Demo-Ort',
    });
  });
});

describe('location filter', () => {
  it('is absent when the parameter is missing or empty', () => {
    expect(parseLocationFilter(undefined, 'de')).toBeUndefined();
    expect(parseLocationFilter('', 'de')).toBeUndefined();
    expect(parseLocationFilter('  ', 'de')).toBeUndefined();
  });

  it('accepts one slug', () => {
    expect(parseLocationFilter('demo-ort', 'de')).toBe('demo-ort');
    expect(parseLocationFilter(' demo-ort ', 'de')).toBe('demo-ort');
  });

  it('rejects malformed, over-long and repeated values', () => {
    for (const value of ['Demo Ort', 'a'.repeat(81), ['demo-ort', 'other'], { slug: 'x' }]) {
      expect(() => parseLocationFilter(value, 'de')).toThrow(ApiError);
    }
  });

  it('keeps only entries of that location, and everything without a filter', () => {
    const items = [
      { slug: 'a', location: { slug: 'demo-ort', name: 'Demo-Ort' } },
      { slug: 'b', location: { slug: 'anderer-ort', name: 'Anderer Ort' } },
      { slug: 'c', location: null },
    ];
    expect(filterByLocation(items, 'demo-ort').map((item) => item.slug)).toEqual(['a']);
    expect(filterByLocation(items, 'unbekannt')).toEqual([]);
    expect(filterByLocation(items, undefined)).toBe(items);
  });
});
