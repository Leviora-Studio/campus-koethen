import { Env } from '../../config/env.schema';
import { MediaError, MediaService } from './media.service';

/**
 * The media endpoint is the one route that answers with bytes. What it will
 * fetch is settled in media.path.spec.ts, what it will FORWARD as a validator
 * in media.conditional.spec.ts; what it will BUFFER is settled here.
 */
const env = {
  STRAPI_BASE_URL: 'http://cms.internal:1337',
  STRAPI_TIMEOUT_MS: 1_000,
} as unknown as Env;

describe('MediaService', () => {
  let fetchMock: jest.SpyInstance;

  afterEach(() => {
    fetchMock?.mockRestore();
  });

  const stubFetch = (impl: (init: RequestInit) => Promise<Response>): void => {
    fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockImplementation((_url, init) => impl(init ?? {}));
  };

  it('serves an allowed image below the size limit', async () => {
    stubFetch(
      async () =>
        new Response(new Uint8Array([1, 2, 3]), {
          status: 200,
          headers: { 'content-type': 'image/png', etag: 'W/"abc"' },
        }),
    );

    const file = await new MediaService(env).fetch('/uploads/foto_5a141d3978.png');
    expect(file).toMatchObject({
      kind: 'file',
      contentType: 'image/png',
      body: Buffer.from([1, 2, 3]),
      etag: 'W/"abc"',
    });
  });

  it('refuses a path outside the upload directory without contacting Strapi', async () => {
    const spy = jest.spyOn(globalThis, 'fetch');
    fetchMock = spy;

    await expect(new MediaService(env).fetch('/etc/passwd')).rejects.toMatchObject({
      kind: 'not-found',
    });
    expect(spy).not.toHaveBeenCalled();
  });

  it('refuses a media type that is not a raster image', async () => {
    stubFetch(
      async () =>
        new Response('<svg/>', { status: 200, headers: { 'content-type': 'image/svg+xml' } }),
    );

    await expect(new MediaService(env).fetch('/uploads/x.svg')).rejects.toMatchObject({
      kind: 'unsupported',
    });
  });

  it('stops the download instead of buffering an oversized image first', async () => {
    // No content-length, so the declared-size pre-check cannot help.
    let pulled = 0;
    const chunk = new Uint8Array(64 * 1024);
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        pulled += 1;
        controller.enqueue(chunk);
      },
    });
    stubFetch(
      async () => new Response(stream, { status: 200, headers: { 'content-type': 'image/png' } }),
    );

    await expect(new MediaService(env).fetch('/uploads/huge.png')).rejects.toMatchObject({
      kind: 'too-large',
    });

    // 12 MiB is 192 chunks. The stream never ends on its own, so anything that
    // finishes at all proves the read was cut short.
    expect(pulled).toBeLessThan(250);
  });

  it('reports a too-large image as too-large, not as unavailable', async () => {
    stubFetch(
      async () =>
        new Response(new Uint8Array(8), {
          status: 200,
          headers: {
            'content-type': 'image/png',
            'content-length': String(MediaService.maxBytes + 1),
          },
        }),
    );

    await expect(new MediaService(env).fetch('/uploads/huge.png')).rejects.toBeInstanceOf(
      MediaError,
    );
    await expect(new MediaService(env).fetch('/uploads/huge.png')).rejects.toMatchObject({
      kind: 'too-large',
    });
  });

  describe('conditional requests', () => {
    /**
     * Captures the headers the service puts on the upstream request.
     *
     * The CMS answers with the image, not a 304: these tests are about what
     * goes OUT, and an upstream that returns 304 to a request that carried no
     * validator is a broken upstream, which the service refuses on purpose.
     */
    const captureHeaders = (): { seen: Record<string, string> | undefined } => {
      const captured: { seen: Record<string, string> | undefined } = { seen: undefined };
      fetchMock = jest
        .spyOn(globalThis, 'fetch')
        .mockImplementation(async (_input, init?: RequestInit) => {
          captured.seen = init?.headers as Record<string, string> | undefined;
          return new Response(new Uint8Array([1, 2, 3]), {
            status: 200,
            headers: { 'content-type': 'image/png', etag: 'W/"abc"' },
          });
        });
      return captured;
    };

    /** Same, but the CMS confirms the client's copy is current. */
    const captureHeadersNotModified = (): { seen: Record<string, string> | undefined } => {
      const captured: { seen: Record<string, string> | undefined } = { seen: undefined };
      fetchMock = jest
        .spyOn(globalThis, 'fetch')
        .mockImplementation(async (_input, init?: RequestInit) => {
          captured.seen = init?.headers as Record<string, string> | undefined;
          return new Response(null, { status: 304, headers: { etag: 'W/"abc"' } });
        });
      return captured;
    };

    it('forwards the client validator and reports a still-current image', async () => {
      const captured = captureHeadersNotModified();

      const result = await new MediaService(env).fetch('/uploads/foto_5a141d3978.png', {
        ifNoneMatch: 'W/"abc"',
      });

      expect(result).toEqual({ kind: 'not-modified', etag: 'W/"abc"' });
      expect(captured.seen).toMatchObject({ 'If-None-Match': 'W/"abc"' });
    });

    it('echoes the client validator when the upstream 304 carries none', async () => {
      fetchMock = jest
        .spyOn(globalThis, 'fetch')
        .mockImplementation(async () => new Response(null, { status: 304 }));

      const result = await new MediaService(env).fetch('/uploads/foto_5a141d3978.png', {
        ifNoneMatch: '"xyz"',
      });

      expect(result).toEqual({ kind: 'not-modified', etag: '"xyz"' });
    });

    it('sends no validator when the client sent none', async () => {
      const captured = captureHeaders();

      await new MediaService(env).fetch('/uploads/foto_5a141d3978.png');

      expect(captured.seen).not.toHaveProperty('If-None-Match');
    });

    for (const [label, value] of [
      ['an unquoted token', 'abc'],
      ['a header-injection attempt', '"a"\r\nX-Injected: 1'],
      // The quotes make this look like one entity-tag, so a grammar that
      // accepts "anything but a quote" between them lets CRLF through into an
      // outgoing header. An entity-tag is visible ASCII only.
      ['a CRLF smuggled INSIDE the quotes', '"a\r\nX-Injected: 1"'],
      ['a NUL byte inside the quotes', '"a\x00b"'],
      ['something far too long', `"${'a'.repeat(300)}"`],
    ] as const) {
      it(`ignores ${label} instead of putting it on an outgoing request`, async () => {
        // Degrading to an unconditional request is the safe direction: the
        // client simply gets the full image, exactly as it did before.
        const captured = captureHeaders();

        await new MediaService(env).fetch('/uploads/foto_5a141d3978.png', { ifNoneMatch: value });

        expect(captured.seen).not.toHaveProperty('If-None-Match');
      });
    }

    it('accepts `*` and a list of tags, which real clients do send', async () => {
      for (const value of ['*', 'W/"a", "b"']) {
        const captured = captureHeaders();
        await new MediaService(env).fetch('/uploads/foto_5a141d3978.png', { ifNoneMatch: value });
        expect(captured.seen).toMatchObject({ 'If-None-Match': value });
        fetchMock.mockRestore();
      }
    });

    it('does not echo a whole tag list as if it were one entity tag', async () => {
      // The client named several tags and the CMS did not say which one it
      // matched. There is no single validator to publish, so none is invented.
      fetchMock = jest
        .spyOn(globalThis, 'fetch')
        .mockImplementation(async () => new Response(null, { status: 304 }));

      const result = await new MediaService(env).fetch('/uploads/foto_5a141d3978.png', {
        ifNoneMatch: 'W/"a", "b"',
      });

      expect(result).toEqual({ kind: 'not-modified', etag: null });
    });

    it('refuses a 304 to a request that carried no validator', async () => {
      // Nothing was asked conditionally, so there is no client copy this could
      // confirm. Treating it as "still current" would serve an empty answer for
      // an image the client may never have seen.
      fetchMock = jest
        .spyOn(globalThis, 'fetch')
        .mockImplementation(async () => new Response(null, { status: 304 }));

      await expect(
        new MediaService(env).fetch('/uploads/foto_5a141d3978.png'),
      ).rejects.toMatchObject({ kind: 'unavailable' });
    });
  });
});
