// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiError } from '../../common/errors/api-error';
import { Env } from '../../config/env.schema';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;

describe('PostsController channels', () => {
  const inA = { slug: 'kanal-a', location: { slug: 'demo-ort', name: 'Demo-Ort' } };
  const none = { slug: 'kanal-b', location: null };
  const controller = new PostsController(
    {
      getChannels: jest.fn(async () => ({ data: [inA, none], translationFallback: false })),
    } as unknown as PostsService,
    {} as Env,
  );

  it('lists every active channel without a location filter', async () => {
    expect((await controller.channels(de, {})).data).toEqual([inA, none]);
  });

  it('keeps only the channels of the requested location', async () => {
    expect((await controller.channels(de, { location: 'demo-ort' })).data).toEqual([inA]);
    expect((await controller.channels(de, { location: 'unbekannt' })).data).toEqual([]);
  });

  it('rejects a malformed location filter', async () => {
    await expect(controller.channels(de, { location: 'Kein Slug' })).rejects.toBeInstanceOf(
      ApiError,
    );
  });
});
