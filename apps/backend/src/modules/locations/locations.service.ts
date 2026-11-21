// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { Injectable } from '@nestjs/common';
import { TtlCache } from '../../common/cache/ttl-cache';
import { ApiError } from '../../common/errors/api-error';
import { StrapiClient, StrapiListResponse, StrapiRequestError } from '../strapi/strapi.client';
import { mapLocationRef } from './location';
import { LocationDto } from './locations.types';

/** Locations change about as rarely as channels. */
const LOCATIONS_CACHE_TTL_MS = 60_000;

/**
 * Read model for /v1/locations: the active campus locations, so a website can
 * learn the slugs it filters channels and calendars by. A location has no
 * language versions and no draft state in the CMS, so there is nothing to
 * localise and nothing unpublished to hide.
 */
@Injectable()
export class LocationsService {
  private readonly cache = new TtlCache<LocationDto[]>(LOCATIONS_CACHE_TTL_MS, 1);

  constructor(private readonly strapi: StrapiClient) {}

  async list(): Promise<LocationDto[]> {
    return this.cache.getOrSet('all', () => this.fetch());
  }

  private async fetch(): Promise<LocationDto[]> {
    let response: StrapiListResponse<unknown>;
    try {
      response = await this.strapi.get<StrapiListResponse<unknown>>('/api/locations', {
        filters: { isActive: { $eq: true } },
        fields: ['slug', 'name'],
        sort: ['name:asc', 'slug:asc'],
        pagination: { pageSize: 100 },
      });
    } catch (error) {
      if (error instanceof StrapiRequestError && error.kind === 'timeout') {
        throw new ApiError('UPSTREAM_TIMEOUT');
      }
      throw new ApiError('UPSTREAM_UNAVAILABLE');
    }
    const entries = Array.isArray(response?.data) ? response.data : [];
    const seen = new Set<string>();
    const locations: LocationDto[] = [];
    for (const entry of entries) {
      const location = mapLocationRef(entry);
      if (!location || seen.has(location.slug)) continue;
      seen.add(location.slug);
      locations.push(location);
    }
    return locations.sort(
      (a, b) => a.name.localeCompare(b.name, 'de') || a.slug.localeCompare(b.slug),
    );
  }
}
