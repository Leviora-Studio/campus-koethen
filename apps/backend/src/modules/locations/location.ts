// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiError } from '../../common/errors/api-error';
import { Locale } from '../../common/locale/locale';
import { LocationDto } from './locations.types';

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
/** The CMS limits a location slug to 80 characters. */
const MAX_SLUG_LENGTH = 80;

/** What a channel or calendar query populates of its location. */
export const LOCATION_POPULATE = { fields: ['slug', 'name', 'isActive'] } as const;

/**
 * Maps a populated location relation. An inactive, missing or malformed
 * location is served as `null`, exactly as if none were set, so a location an
 * editor retires disappears from every channel and calendar at once.
 */
export function mapLocationRef(raw: unknown): LocationDto | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const record = raw as Record<string, unknown>;
  const slug = record['slug'];
  const name = record['name'];
  if (typeof slug !== 'string' || !SLUG_PATTERN.test(slug) || slug.length > MAX_SLUG_LENGTH) {
    return null;
  }
  if (typeof name !== 'string' || name.trim().length === 0) return null;
  if (record['isActive'] === false) return null;
  return { slug, name };
}

/**
 * The optional `location` query parameter: exactly one location slug.
 * Absent or empty means "no filter"; anything else malformed is a 400.
 */
export function parseLocationFilter(raw: unknown, locale: Locale): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string') {
    throw new ApiError('VALIDATION_FAILED', locale, ['location: exactly one location slug']);
  }
  const value = raw.trim();
  if (value.length === 0) return undefined;
  if (value.length > MAX_SLUG_LENGTH || !SLUG_PATTERN.test(value)) {
    throw new ApiError('VALIDATION_FAILED', locale, ['location: invalid location slug']);
  }
  return value;
}

/** Keeps the entries of one location; without a filter, the list is returned as it is. */
export function filterByLocation<T extends { location: LocationDto | null }>(
  items: T[],
  location: string | undefined,
): T[] {
  if (location === undefined) return items;
  return items.filter((item) => item.location?.slug === location);
}
