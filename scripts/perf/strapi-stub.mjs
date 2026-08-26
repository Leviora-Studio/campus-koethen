/**
 * Deterministic stand-in for Strapi, used only by the performance baseline.
 *
 * Why a stub rather than the real CMS: a baseline has to separate the cost this
 * codebase controls from the cost it merely waits for. With the real Strapi in
 * the loop, `/v1/posts` measures Strapi's query planner, its own Node process
 * and the network hop — none of which any optimisation in `apps/backend` can
 * change. The stub answers in a known, near-zero time, so what remains in the
 * measurement is exactly the part LEVIORA-184 can act on: request encoding,
 * bounded reading, JSON parsing, block sanitising, DTO mapping, serialisation
 * and compression.
 *
 * `--upstream-delay-ms` puts a controlled latency back in, which is how the
 * baseline shows what the TTL cache is worth without pretending to know the
 * real CMS's response time.
 *
 * This is test scaffolding. It is never started by the app, never referenced
 * from application code, and serves only clearly synthetic content.
 */

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const port = Number(arg('port', '4599'));
const upstreamDelayMs = Number(arg('upstream-delay-ms', '0'));

/** Deterministic PRNG so two runs generate identical payloads. */
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const WORDS =
  'Campus Studium Semester Vorlesung Bibliothek Mensa Termin Hinweis Anmeldung Prüfung Projekt Werkstatt Beratung Formular Frist Gremium Fachschaft Labor Exkursion Workshop'.split(
    ' ',
  );

function sentence(random, words) {
  const parts = Array.from({ length: words }, () => WORDS[Math.floor(random() * WORDS.length)]);
  return `${parts.join(' ')}.`;
}

/**
 * One article body.
 *
 * Sized from the editorial guideline in docs/content-editor-guide.md: a normal
 * post is a handful of paragraphs with the occasional heading, list and image.
 * 14 blocks and roughly 2.5 kB of text is a long post, not an average one, so
 * the mapping cost the baseline reports is an upper bound for real content.
 */
function contentBlocks(random) {
  const blocks = [];
  for (let i = 0; i < 14; i += 1) {
    if (i % 5 === 0) {
      blocks.push({
        type: 'heading',
        level: 2,
        children: [{ type: 'text', text: sentence(random, 4) }],
      });
    } else if (i % 7 === 3) {
      blocks.push({
        type: 'list',
        format: 'unordered',
        children: Array.from({ length: 4 }, () => ({
          type: 'list-item',
          children: [{ type: 'text', text: sentence(random, 8) }],
        })),
      });
    } else if (i % 11 === 6) {
      blocks.push({
        type: 'image',
        image: {
          url: `/uploads/perf-inline-${i}.jpg`,
          alternativeText: sentence(random, 3),
          width: 1200,
          height: 675,
        },
        children: [{ type: 'text', text: '' }],
      });
    } else {
      blocks.push({
        type: 'paragraph',
        children: [
          { type: 'text', text: sentence(random, 22) },
          {
            type: 'link',
            url: 'https://example.invalid/quelle',
            children: [{ type: 'text', text: 'Quelle' }],
          },
          { type: 'text', text: ` ${sentence(random, 12)}` },
        ],
      });
    }
  }
  return blocks;
}

const CHANNELS = Array.from({ length: 8 }, (_, i) => ({
  id: i + 1,
  documentId: `perf-channel-${i}`,
  slug: `perf-channel-${i}`,
  name: `Perf-Kanal ${i}`,
  description: 'Synthetischer Kanal für die Performance-Baseline.',
  colorHex: '#5B3FD0',
  sortOrder: i * 10,
  defaultSubscribed: i < 2,
  locale: 'de',
}));

const TAGS = Array.from({ length: 24 }, (_, i) => ({
  id: i + 1,
  documentId: `perf-tag-${i}`,
  slug: `perf-tag-${i}`,
  name: `Perf-Tag ${i}`,
  description: null,
  iconKey: 'tag',
  colorHex: '#3366CC',
  sortOrder: i,
  locale: 'de',
}));

/** 240 posts: a couple of years of editorial output at the planned cadence. */
const POSTS = Array.from({ length: 240 }, (_, i) => {
  const random = rng(7000 + i);
  const isEvent = i % 3 === 0;
  const start = new Date(Date.UTC(2026, 2, 2 + (i % 60), 10, 0, 0));
  return {
    id: i + 1,
    documentId: `perf-post-${i}`,
    slug: `perf-post-${i}`,
    title: `Perf-Beitrag ${i}: ${sentence(random, 5)}`,
    teaser: sentence(random, 26),
    content: contentBlocks(random),
    sourceName: 'Synthetische Quelle',
    sourceUrl: 'https://example.invalid/quelle',
    kind: isEvent ? 'event' : 'news',
    publishedAt: new Date(Date.UTC(2026, 1, 1 + (i % 28), 8, 0, 0)).toISOString(),
    updatedAt: new Date(Date.UTC(2026, 1, 2 + (i % 28), 8, 0, 0)).toISOString(),
    eventStart: isEvent ? start.toISOString() : null,
    eventEnd: isEvent ? new Date(start.getTime() + 7_200_000).toISOString() : null,
    eventLocation: isEvent ? `Raum ${100 + (i % 40)}` : null,
    locale: 'de',
    heroImage: {
      url: `/uploads/perf-hero-${i % 20}.jpg`,
      alternativeText: 'Synthetisches Titelbild',
      width: 1600,
      height: 900,
    },
    isPinned: i % 40 === 0,
    validFrom: null,
    validUntil: null,
    // Field names follow posts.mapper.ts exactly: a post without `tag` and
    // `primaryChannel` is dropped by the mapper, which would silently turn the
    // list route into a measurement of an empty response.
    tag: TAGS[i % TAGS.length],
    primaryChannel: CHANNELS[i % CHANNELS.length],
    channels: [CHANNELS[i % CHANNELS.length], CHANNELS[(i + 3) % CHANNELS.length]],
  };
});

// Field names follow contacts.service.ts: `persons`, `shortDescription`.
const CONTACT_AREAS = Array.from({ length: 14 }, (_, i) => ({
  id: i + 1,
  documentId: `perf-area-${i}`,
  slug: `perf-area-${i}`,
  name: `Perf-Bereich ${i}`,
  shortDescription: 'Synthetischer Kontaktbereich für die Performance-Baseline.',
  description: 'Synthetischer Kontaktbereich für die Performance-Baseline.',
  iconKey: 'info',
  sortOrder: i * 10,
  isActive: true,
  isDemoContent: true,
  locale: 'de',
  persons: Array.from({ length: 6 }, (_, j) => ({
    id: i * 10 + j,
    documentId: `perf-person-${i}-${j}`,
    name: `Perf-Person ${i}-${j}`,
    role: 'Synthetische Rolle',
    description: 'Synthetische Beschreibung.',
    email: null,
    phone: null,
    website: null,
    isActive: true,
    sortOrder: j,
    rooms: [],
  })),
}));

/**
 * Rooms, keyed to the catalogue the API actually joins against.
 *
 * This used to invent 420 `perf-room-N` keys. That worked until the room model
 * was simplified (commit 0406bc7): `RoomsService.map` now looks every roomKey
 * up in the bundled `@campus/map` catalogue and DROPS the row when it is not
 * there, because technical room data is owned by the catalogue and no longer
 * by Strapi. Invented keys are in no catalogue, so all 420 were discarded and
 * `/v1/rooms` answered with an empty list — 93 bytes where the baseline in
 * section 6 records 107.7 kB. The route kept being measured and kept looking
 * fast, while measuring nothing at all (found in LEVIORA-185).
 *
 * Reading the real catalogue is what keeps that from happening again: the keys
 * are correct by construction, and the response size follows the catalogue
 * instead of a number typed here. The editorial overlay — display name and
 * description — stays synthetic, which is all Strapi owns for a room.
 */
const catalogPath = new URL(
  '../../packages/campus-map/catalog/campus-map.catalog.json',
  import.meta.url,
);
const mapCatalog = JSON.parse(await readFile(catalogPath, 'utf8'));

const ROOMS = mapCatalog.rooms.map((room, i) => ({
  id: i + 1,
  documentId: `perf-room-${room.roomKey}`,
  roomKey: room.roomKey,
  roomNumber: room.roomNumber,
  buildingKey: room.buildingKey,
  floorKey: room.floorKey,
  roomType: room.roomType,
  displayName: `Perf-Raum ${room.roomNumber}`,
  description: 'Synthetischer Raumtext für die Performance-Baseline.',
  mapVersion: mapCatalog.mapVersion,
  sortOrder: room.sortOrder,
  catalogActive: true,
  isVisible: true,
  locale: 'de',
}));

if (ROOMS.length === 0) {
  throw new Error(
    `The campus-map catalogue at ${catalogPath.pathname} contains no rooms. ` +
      '/v1/rooms would be measured as an empty response.',
  );
}

/** Strapi's bracket query syntax, only as far as the callers actually use it. */
function parseQuery(url) {
  const parsed = new URL(url, 'http://stub.invalid');
  const pageSize = Number(parsed.searchParams.get('pagination[pageSize]') ?? 25);
  const page = Number(parsed.searchParams.get('pagination[page]') ?? 1);
  const slugIn = [];
  for (const [key, value] of parsed.searchParams.entries()) {
    if (key.startsWith('filters[slug][$in]')) slugIn.push(value);
  }
  const slugEq = parsed.searchParams.get('filters[slug][$eq]');
  const kind = parsed.searchParams.get('filters[kind][$eq]');
  return { path: parsed.pathname, pageSize, page, slugIn, slugEq, kind };
}

function listResponse(all, { page, pageSize }) {
  const start = (page - 1) * pageSize;
  const data = all.slice(start, start + pageSize);
  return {
    data,
    meta: {
      pagination: {
        page,
        pageSize,
        pageCount: Math.max(1, Math.ceil(all.length / Math.max(pageSize, 1))),
        total: all.length,
      },
    },
  };
}

function resolve(query) {
  switch (query.path) {
    case '/api/channels':
      return listResponse(CHANNELS, query);
    case '/api/tags':
      return listResponse(TAGS, query);
    case '/api/contact-areas':
      return listResponse(CONTACT_AREAS, query);
    case '/api/rooms':
      return listResponse(ROOMS, query);
    case '/api/posts': {
      let all = POSTS;
      if (query.kind) all = all.filter((p) => p.kind === query.kind);
      if (query.slugEq) all = all.filter((p) => p.slug === query.slugEq);
      if (query.slugIn.length > 0) all = all.filter((p) => query.slugIn.includes(p.slug));
      return listResponse(all, query);
    }
    default:
      return null;
  }
}

const server = createServer((req, res) => {
  const query = parseQuery(req.url ?? '/');
  const send = () => {
    const body = resolve(query);
    if (!body) {
      res.writeHead(404, { 'content-type': 'application/json' });
      res.end('{"data":[],"meta":{}}');
      return;
    }
    const payload = JSON.stringify(body);
    res.writeHead(200, {
      'content-type': 'application/json',
      'content-length': Buffer.byteLength(payload),
    });
    res.end(payload);
  };
  if (upstreamDelayMs > 0) setTimeout(send, upstreamDelayMs);
  else send();
});

server.listen(port, '127.0.0.1', () => {
  process.stdout.write(
    `strapi-stub listening on 127.0.0.1:${port} (upstream delay ${upstreamDelayMs} ms)\n`,
  );
});
