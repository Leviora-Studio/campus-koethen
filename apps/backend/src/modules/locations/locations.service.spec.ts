// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiError } from '../../common/errors/api-error';
import { StrapiClient, StrapiRequestError } from '../strapi/strapi.client';
import { LocationsService } from './locations.service';

const location = (slug: string, name: string, over: Record<string, unknown> = {}) => ({
  id: 1,
  documentId: `doc-${slug}`,
  slug,
  name,
  isActive: true,
  ...over,
});

function service(handler: () => unknown) {
  const get = jest.fn(async (_path: string, _query: Record<string, unknown>) => handler());
  return { service: new LocationsService({ get } as unknown as StrapiClient), get };
}

describe('LocationsService', () => {
  it('lists active locations by name with slug and name only', async () => {
    const { service: locations, get } = service(() => ({
      data: [location('demo-b', 'Demo B'), location('demo-a', 'Demo A')],
    }));

    expect(await locations.list()).toEqual([
      { slug: 'demo-a', name: 'Demo A' },
      { slug: 'demo-b', name: 'Demo B' },
    ]);
    const [path, query] = get.mock.calls[0]!;
    expect(path).toBe('/api/locations');
    expect(query).toMatchObject({ filters: { isActive: { $eq: true } }, fields: ['slug', 'name'] });
    expect(query).not.toHaveProperty('locale');
  });

  it('drops malformed and inactive entries instead of failing the list', async () => {
    const { service: locations } = service(() => ({
      data: [
        location('demo-a', 'Demo A'),
        location('Kaputt', 'Kaputt'),
        location('demo-b', 'Demo B', { isActive: false }),
        'not an object',
      ],
    }));

    expect(await locations.list()).toEqual([{ slug: 'demo-a', name: 'Demo A' }]);
  });

  it('serves a repeat request from the cache', async () => {
    const { service: locations, get } = service(() => ({ data: [location('demo-a', 'Demo A')] }));

    await locations.list();
    await locations.list();

    expect(get).toHaveBeenCalledTimes(1);
  });

  it('reports an unreachable CMS as an upstream error', async () => {
    const { service: unavailable } = service(() => {
      throw new StrapiRequestError('unavailable', 'down');
    });
    const { service: timeout } = service(() => {
      throw new StrapiRequestError('timeout', 'slow');
    });

    await expect(unavailable.list()).rejects.toMatchObject({ code: 'UPSTREAM_UNAVAILABLE' });
    await expect(timeout.list()).rejects.toBeInstanceOf(ApiError);
    await expect(timeout.list()).rejects.toMatchObject({ code: 'UPSTREAM_TIMEOUT' });
  });
});
