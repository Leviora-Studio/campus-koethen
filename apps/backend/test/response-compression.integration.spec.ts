import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { request as httpRequest, IncomingHttpHeaders, Server } from 'http';
import { AddressInfo } from 'net';
import { brotliDecompressSync, gunzipSync } from 'zlib';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { createResponseCompression } from '../src/common/http/response-compression';
import { AppModule } from '../src/app.module';
import { ContactsService } from '../src/modules/contacts/contacts.service';
import { MediaService } from '../src/modules/media/media.service';

// Starting the real Nest application can exceed Jest's 5s default on shared CI.
jest.setTimeout(60_000);

interface RawResponse {
  status: number;
  headers: IncomingHttpHeaders;
  /** The bytes as they came off the socket — NOT transparently decoded. */
  body: Buffer;
}

/**
 * A GET whose request headers are exactly what is passed in.
 *
 * Supertest is not usable here: superagent always sends an `Accept-Encoding`
 * of its own and silently decodes what comes back, which is precisely the two
 * things these tests are about. Node's client adds neither.
 */
async function rawGet(
  port: number,
  path: string,
  headers: Record<string, string> = {},
): Promise<RawResponse> {
  return new Promise<RawResponse>((resolve, reject) => {
    const req = httpRequest({ host: '127.0.0.1', port, path, method: 'GET', headers }, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (chunk: Buffer) => chunks.push(chunk));
      res.on('end', () =>
        resolve({ status: res.statusCode ?? 0, headers: res.headers, body: Buffer.concat(chunks) }),
      );
      res.on('error', reject);
    });
    req.on('error', reject);
    req.end();
  });
}

/** An index big enough to be worth compressing, and as repetitive as the real one. */
function searchIndexFixture(areaCount: number): unknown[] {
  return Array.from({ length: areaCount }, (_, index) => ({
    slug: `bereich-${index}`,
    name: `Beispielbereich ${index}`,
    shortDescription: 'Ein Beispielbereich der Demo-Daten, ausdrücklich als Demo gekennzeichnet.',
    iconKey: 'students-council',
    descriptionText:
      'Dieser Text steht stellvertretend für eine redaktionelle Bereichsbeschreibung und ' +
      'wiederholt sich über alle Bereiche hinweg, genau wie im echten Suchindex.',
    generalEmail: null,
    phone: null,
    website: null,
    appointmentBookingUrl: null,
    address: null,
    openingHours: null,
    rooms: [{ roomKey: `demo-${index}`, label: `Raum ${index}`, building: 'Demo', floor: '1' }],
    persons: [],
  }));
}

/**
 * Transport compression, end to end over a real socket.
 *
 * The unit test decides WHICH responses are eligible; this one proves what
 * actually reaches the client: that an offered encoding is used, that the
 * decoded bytes are unchanged, that a client which offers nothing gets the
 * identical response it got before, and that the one byte-serving endpoint is
 * left alone.
 *
 * The services are stubbed — this is about the transport, not about Strapi.
 */
describe('response compression (integration)', () => {
  let app: INestApplication;
  let port: number;

  const pngBytes = Buffer.alloc(64 * 1024, 0x7f);

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ContactsService)
      .useValue({
        listAreas: async () => ({ data: [], translationFallback: false }),
        searchIndex: async () => ({ data: searchIndexFixture(40), translationFallback: false }),
        getArea: async () => ({ data: {}, translationFallback: false, droppedBlockTypes: [] }),
      })
      .overrideProvider(MediaService)
      .useValue({
        fetch: async () => ({ body: pngBytes, contentType: 'image/png', etag: '"demo"' }),
      })
      .compile();

    app = moduleRef.createNestApplication({ logger: false });
    app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });
    // The same registration order as main.ts: ahead of every route.
    app.use(createResponseCompression());
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.listen(0, '127.0.0.1');

    port = ((app.getHttpServer() as Server).address() as AddressInfo).port;
  });

  afterAll(async () => {
    await app?.close();
  });

  const searchIndex = '/v1/contact-areas/search-index';

  it('gzips a large JSON response when the client offers gzip', async () => {
    const response = await rawGet(port, searchIndex, { 'Accept-Encoding': 'gzip' });

    expect(response.status).toBe(200);
    expect(response.headers['content-encoding']).toBe('gzip');
    expect(response.headers['vary']).toContain('Accept-Encoding');
    expect(gunzipSync(response.body).length).toBeGreaterThan(response.body.length);
  });

  it('prefers brotli when the client offers it', async () => {
    const response = await rawGet(port, searchIndex, { 'Accept-Encoding': 'br, gzip' });

    expect(response.headers['content-encoding']).toBe('br');
    expect(brotliDecompressSync(response.body).length).toBeGreaterThan(response.body.length);
  });

  it('changes nothing but the encoding — the decoded payload is the identical response', async () => {
    const plain = await rawGet(port, searchIndex);
    const gzipped = await rawGet(port, searchIndex, { 'Accept-Encoding': 'gzip' });
    const brotli = await rawGet(port, searchIndex, { 'Accept-Encoding': 'br' });

    expect(gunzipSync(gzipped.body).equals(plain.body)).toBe(true);
    expect(brotliDecompressSync(brotli.body).equals(plain.body)).toBe(true);
    expect((JSON.parse(plain.body.toString('utf8')) as { data: unknown[] }).data).toHaveLength(40);
  });

  it('leaves the response untouched when the client offers no encoding at all', async () => {
    const response = await rawGet(port, searchIndex);

    expect(response.status).toBe(200);
    expect(response.headers['content-encoding']).toBeUndefined();
    // A body of known length is the proof that nothing was re-chunked either.
    expect(response.headers['content-length']).toBe(String(response.body.length));
  });

  it('leaves the response untouched when the client asks for identity', async () => {
    const response = await rawGet(port, searchIndex, { 'Accept-Encoding': 'identity' });

    expect(response.headers['content-encoding']).toBeUndefined();
  });

  it('does not compress a response below the threshold', async () => {
    // The area list is stubbed empty, so this response is a few dozen bytes.
    const response = await rawGet(port, '/v1/contact-areas', { 'Accept-Encoding': 'gzip, br' });

    expect(response.status).toBe(200);
    expect(response.body.length).toBeLessThan(1024);
    expect(response.headers['content-encoding']).toBeUndefined();
  });

  it('does not compress the media endpoint a second time', async () => {
    const response = await rawGet(port, '/v1/media/uploads/demo_0123456789.png', {
      'Accept-Encoding': 'gzip, br',
    });

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toBe('image/png');
    expect(response.headers['content-encoding']).toBeUndefined();
    expect(response.body.equals(pngBytes)).toBe(true);
  });
});
