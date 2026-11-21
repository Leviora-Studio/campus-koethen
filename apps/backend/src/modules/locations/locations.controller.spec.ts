// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { LocationsController } from './locations.controller';
import { LocationsService } from './locations.service';

describe('LocationsController', () => {
  it('serves the active locations with the usual locale meta', async () => {
    const data = [{ slug: 'demo-ort', name: 'Demo-Ort' }];
    const controller = new LocationsController({
      list: jest.fn(async () => data),
    } as unknown as LocationsService);

    const response = await controller.list({ requestedLocale: 'en', resolvedLocale: 'en' });

    expect(response.data).toEqual(data);
    expect(response.meta).toMatchObject({
      requestedLocale: 'en',
      resolvedLocale: 'en',
      translationFallback: false,
    });
  });
});
