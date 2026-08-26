import { Env, validateEnv } from '../../config/env.schema';
import { CanteenSourceError, MeineMensaClient } from './meine-mensa.client';

/**
 * What this client will BUFFER and WHO it will talk to.
 *
 * The mapping and the retry policy are covered by the sync tests; what is
 * settled here are the two limits that nothing else enforces — how many bytes
 * of a third-party answer may reach the heap, and whether that third party may
 * redirect the worker onto a host of its choosing.
 */

function makeEnv(overrides: Record<string, string> = {}): Env {
  return validateEnv({
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    CANTEEN_RETRY_ATTEMPTS: '0',
    CANTEEN_HTTP_TIMEOUT_MS: '1000',
    ...overrides,
  });
}

const request = { locationId: 1, from: '2026-03-01', to: '2026-03-02' };

const validBody = JSON.stringify({
  data: [
    {
      id: 1,
      date: '2026-03-01',
      location_id: 1,
      food: { name: 'Linseneintopf', price_1: 2.5 },
    },
  ],
});

function jsonResponse(body: string, init: ResponseInit = {}): Response {
  return new Response(body, {
    status: 200,
    headers: { 'content-type': 'application/json' },
    ...init,
  });
}

/** A body that never ends — the shape a post-hoc length check cannot defend. */
function endlessStream(chunkBytes: number, onPull: () => void): ReadableStream<Uint8Array> {
  const chunk = new Uint8Array(chunkBytes).fill(0x20);
  return new ReadableStream<Uint8Array>({
    pull(controller) {
      onPull();
      controller.enqueue(chunk);
    },
  });
}

describe('MeineMensaClient', () => {
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

  it('parses a valid answer', async () => {
    stubFetch(async () => jsonResponse(validBody));

    const result = await new MeineMensaClient(makeEnv()).fetchFoodPlans(request);

    expect(result.data).toHaveLength(1);
    expect(result.data[0]?.food.name).toBe('Linseneintopf');
  });

  it('refuses to follow a redirect instead of letting the source pick the host', async () => {
    let seen: RequestInit = {};
    stubFetch(async (_url, init) => {
      seen = init;
      return jsonResponse(validBody);
    });

    await new MeineMensaClient(makeEnv()).fetchFoodPlans(request);

    // `follow` — the fetch default — would let a redirect from the source aim
    // this worker at any host, including one inside our own network.
    expect(seen.redirect).toBe('error');
  });

  it('reports a non-JSON body as malformed rather than throwing a parse error', async () => {
    stubFetch(async () => jsonResponse('<html>nope</html>'));

    await expect(new MeineMensaClient(makeEnv()).fetchFoodPlans(request)).rejects.toMatchObject({
      kind: 'malformed',
    });
  });

  it('stops the download instead of buffering an oversized body first', async () => {
    let pulled = 0;
    stubFetch(async () => new Response(endlessStream(64 * 1024, () => (pulled += 1))));

    await expect(
      new MeineMensaClient(makeEnv({ CANTEEN_MAX_RESPONSE_BYTES: '640000' })).fetchFoodPlans(
        request,
      ),
    ).rejects.toBeInstanceOf(CanteenSourceError);

    // 640_000 bytes is ten chunks; the stream never ends on its own, so
    // finishing at all is what proves the read was cut short rather than
    // drained into memory.
    expect(pulled).toBeLessThan(50);
  });

  it('classifies an oversized body as malformed and does not retry it', async () => {
    let calls = 0;
    stubFetch(async () => {
      calls += 1;
      return new Response(
        endlessStream(64 * 1024, () => undefined),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    });

    await expect(
      new MeineMensaClient(
        makeEnv({ CANTEEN_MAX_RESPONSE_BYTES: '640000', CANTEEN_RETRY_ATTEMPTS: '3' }),
      ).fetchFoodPlans(request),
    ).rejects.toMatchObject({ kind: 'malformed' });

    // A flood is a deterministic answer; asking again would only pull it again.
    expect(calls).toBe(1);
  });
});
