import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Env, validateEnv } from '../../config/env.schema';
import { WebUntisClient, WebUntisError } from './webuntis.client';

const fixtureText = (name: string): string =>
  readFileSync(join(__dirname, '../../../test/fixtures/webuntis', name), 'utf8');

function makeEnv(overrides: Record<string, string> = {}): Env {
  return validateEnv({
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    WEBUNTIS_ENABLED: 'true',
    WEBUNTIS_RETRY_ATTEMPTS: '2',
    WEBUNTIS_REQUEST_SPACING_MS: '0',
    WEBUNTIS_HTTP_TIMEOUT_MS: '1000',
    ...overrides,
  });
}

function jsonResponse(body: string, init: ResponseInit = {}): Response {
  return new Response(body, {
    status: 200,
    headers: { 'content-type': 'application/json;charset=utf-8' },
    ...init,
  });
}

describe('WebUntisClient', () => {
  let fetchMock: jest.SpyInstance;

  afterEach(() => {
    fetchMock?.mockRestore();
  });

  const stubFetch = (impl: (url: string, init: RequestInit) => Promise<Response>) => {
    fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockImplementation((input: string | URL | Request, init?: RequestInit) =>
        impl(
          typeof input === 'string' ? input : input instanceof URL ? input.href : input.url,
          init ?? {},
        ),
      );
    return fetchMock;
  };

  describe('request shaping', () => {
    it('sends the anonymous school header and asks for JSON', async () => {
      let seen: RequestInit = {};
      stubFetch(async (_url, init) => {
        seen = init;
        return jsonResponse(fixtureText('app-data.json'));
      });

      await new WebUntisClient(makeEnv()).fetchAppData();

      const headers = seen.headers as Record<string, string>;
      expect(headers['anonymous-school']).toBe('hsa');
      expect(headers['Accept']).toContain('application/json');
      expect(seen.redirect).toBe('error');
    });

    it('omits the school year header until a context is known', async () => {
      let seen: RequestInit = {};
      stubFetch(async (_url, init) => {
        seen = init;
        return jsonResponse(fixtureText('app-data.json'));
      });

      await new WebUntisClient(makeEnv()).fetchAppData();

      expect(Object.keys(seen.headers as Record<string, string>)).not.toContain(
        'X-Webuntis-Api-School-Year-Id',
      );
    });

    it('sends the resolved school year header on catalogue requests', async () => {
      let seen: RequestInit = {};
      stubFetch(async (_url, init) => {
        seen = init;
        return jsonResponse(fixtureText('filter-classes.json'));
      });

      await new WebUntisClient(makeEnv()).fetchClasses(49);

      expect((seen.headers as Record<string, string>)['X-Webuntis-Api-School-Year-Id']).toBe('49');
    });

    it('requests entries with the verified parameter set', async () => {
      let seenUrl = '';
      stubFetch(async (url) => {
        seenUrl = url;
        return jsonResponse(fixtureText('entries-week.json'));
      });

      await new WebUntisClient(makeEnv()).fetchEntries(49, '2026-07-20', '2026-07-24');

      expect(seenUrl).toContain('start=2026-07-20');
      expect(seenUrl).toContain('end=2026-07-24');
      expect(seenUrl).toContain('format=2');
      expect(seenUrl).toContain('resourceType=CLASS');
      // No resource ids: one request covers every class. That is the whole
      // reason this feature does not need a demand-based cache.
      expect(seenUrl).not.toContain('resources=');
    });
  });

  describe('error classification', () => {
    it('classifies an HTML login page instead of trying to parse it', async () => {
      stubFetch(
        async () =>
          new Response(fixtureText('login.html'), {
            status: 200,
            headers: { 'content-type': 'text/html;charset=utf-8' },
          }),
      );

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toMatchObject({
        kind: 'html',
      });
    });

    it('classifies unparseable JSON as malformed', async () => {
      stubFetch(async () => jsonResponse(fixtureText('malformed.json')));

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toMatchObject({
        kind: 'malformed',
      });
    });

    it('classifies a schema violation as malformed', async () => {
      stubFetch(async () => jsonResponse('{"currentSchoolYear":{"name":"x"}}'));

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toMatchObject({
        kind: 'malformed',
      });
    });

    it('classifies a rate limit', async () => {
      stubFetch(async () => new Response('slow down', { status: 429 }));

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toMatchObject({
        kind: 'rate_limited',
      });
    });

    it('classifies a timeout', async () => {
      stubFetch(
        async (_url, init) =>
          new Promise((_resolve, reject) => {
            init.signal?.addEventListener('abort', () => {
              const error = new Error('aborted');
              error.name = 'AbortError';
              reject(error);
            });
          }),
      );

      await expect(
        new WebUntisClient(makeEnv({ WEBUNTIS_HTTP_TIMEOUT_MS: '1000' })).fetchAppData(),
      ).rejects.toMatchObject({ kind: 'timeout' });
    }, 20_000);

    it('refuses a response that exceeds the size guard', async () => {
      stubFetch(async () =>
        jsonResponse('{}', {
          headers: { 'content-type': 'application/json', 'content-length': '999999999' },
        }),
      );

      await expect(
        new WebUntisClient(makeEnv({ WEBUNTIS_MAX_RESPONSE_BYTES: '100000' })).fetchAppData(),
      ).rejects.toMatchObject({ kind: 'malformed' });
    });

    it('stops the download instead of buffering an oversized response first', async () => {
      // No content-length, so the declared-size pre-check cannot help. The old
      // guard ran after `response.text()` — the body was already in memory.
      let pulled = 0;
      const chunk = new TextEncoder().encode('X'.repeat(1024));
      const stream = new ReadableStream<Uint8Array>({
        pull(controller) {
          pulled += 1;
          controller.enqueue(chunk);
        },
      });
      stubFetch(
        async () =>
          new Response(stream, {
            status: 200,
            headers: { 'content-type': 'application/json' },
          }),
      );

      await expect(
        new WebUntisClient(
          makeEnv({ WEBUNTIS_MAX_RESPONSE_BYTES: '64000', WEBUNTIS_RETRY_ATTEMPTS: '0' }),
        ).fetchAppData(),
      ).rejects.toMatchObject({ kind: 'malformed' });

      // 64000 bytes is ~63 chunks; the stream never ends on its own.
      expect(pulled).toBeLessThan(100);
    });

    it('refuses to call upstream at all when the feature is disabled', async () => {
      const spy = stubFetch(async () => jsonResponse(fixtureText('app-data.json')));

      await expect(
        new WebUntisClient(makeEnv({ WEBUNTIS_ENABLED: 'false' })).fetchAppData(),
      ).rejects.toMatchObject({ kind: 'disabled' });
      expect(spy).not.toHaveBeenCalled();
    });
  });

  describe('retry behaviour', () => {
    it('retries a 5xx and succeeds', async () => {
      let calls = 0;
      stubFetch(async () => {
        calls += 1;
        return calls === 1
          ? new Response('boom', { status: 503 })
          : jsonResponse(fixtureText('app-data.json'));
      });

      const data = await new WebUntisClient(makeEnv()).fetchAppData();

      expect(calls).toBe(2);
      expect(data.currentSchoolYear.id).toBe(49);
    });

    it('does NOT retry a deterministic 4xx', async () => {
      let calls = 0;
      stubFetch(async () => {
        calls += 1;
        return new Response('nope', { status: 404 });
      });

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toMatchObject({
        kind: 'http',
      });
      expect(calls).toBe(1);
    });

    it('does NOT retry malformed content, which would not fix itself', async () => {
      let calls = 0;
      stubFetch(async () => {
        calls += 1;
        return jsonResponse('{ broken');
      });

      await expect(new WebUntisClient(makeEnv()).fetchAppData()).rejects.toBeInstanceOf(
        WebUntisError,
      );
      expect(calls).toBe(1);
    });

    it('gives up after the configured attempts', async () => {
      let calls = 0;
      stubFetch(async () => {
        calls += 1;
        return new Response('boom', { status: 500 });
      });

      await expect(
        new WebUntisClient(makeEnv({ WEBUNTIS_RETRY_ATTEMPTS: '2' })).fetchAppData(),
      ).rejects.toMatchObject({ kind: 'http' });
      expect(calls).toBe(3);
    });
  });

  describe('redaction', () => {
    it('never puts the upstream host, headers or body into the error message', async () => {
      stubFetch(
        async () =>
          new Response('<html><body>Anmelden Joshua Garvey</body></html>', {
            status: 200,
            headers: { 'content-type': 'text/html' },
          }),
      );

      try {
        await new WebUntisClient(makeEnv()).fetchAppData();
        throw new Error('expected a failure');
      } catch (error) {
        const text = `${(error as Error).message} ${JSON.stringify(error)}`;
        expect(text).not.toContain('webuntis.com');
        expect(text).not.toContain('anonymous-school');
        expect(text).not.toContain('Joshua');
        expect(text).not.toContain('<html');
      }
    });
  });
});
