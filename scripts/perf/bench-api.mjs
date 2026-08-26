/**
 * Latency harness for the Campus API baseline.
 *
 * Method, stated so a later run can be compared honestly:
 *
 *   cold   One request per route, issued before any other traffic touches that
 *          route. It carries the first-call costs a real first user pays:
 *          an empty TTL cache, an unprepared statement, a cold JIT.
 *   warm   `--warmup` requests are sent and discarded, then `--iterations`
 *          requests are measured. Requests are sequential, because the number
 *          this baseline is about is service time per request, not the
 *          throughput of a saturated process.
 *
 * Reported: p50/p90/p95/p99/max over the warm sample, plus the cold value and
 * the uncompressed response size. Percentiles come from the sorted sample with
 * nearest-rank, so a p95 always names a request that really happened.
 *
 * Timing uses the monotonic clock and measures until the body is fully read —
 * a header-only stopwatch would hide serialisation and compression, which is
 * exactly where server-side work shows up.
 *
 * Usage:
 *   node scripts/perf/bench-api.mjs --base-url http://127.0.0.1:3000 \
 *     --iterations 200 --warmup 20 --out artifacts/api-baseline.json
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};

const baseUrl = (arg('base-url', 'http://127.0.0.1:3000') ?? '').replace(/\/+$/, '');
const iterations = Number(arg('iterations', '200'));
const warmup = Number(arg('warmup', '20'));
const outFile = arg('out', '');
const label = arg('label', 'baseline');

/**
 * The routes a baseline has to cover.
 *
 * Selection rule: every route the app calls on a normal day, plus the two that
 * are unbounded by nature (aggregated calendar events, timetable week). Routes
 * that only an operator calls are out — a budget for /health/ready would be a
 * number nobody acts on.
 *
 * `minBytes` is a FLOOR, not an expected size: it is set roughly an order of
 * magnitude below what the route really returns, so a payload that legitimately
 * shrinks — an editorial field dropped, say — passes, while a route that has
 * effectively stopped answering fails the run. See the note at the check itself
 * for the case that made this necessary.
 */
const ROUTES = [
  { name: 'health-live', minBytes: 30, path: '/health/live', tier: 'probe' },
  { name: 'canteens-list', minBytes: 300, path: '/v1/canteens?locale=de', tier: 'app-start' },
  {
    name: 'canteen-menu-7d',
    minBytes: 40000,
    path: '/v1/canteens/perf-canteen-1/menu?locale=de&from=2026-03-02&to=2026-03-08',
    tier: 'primary',
  },
  {
    name: 'canteen-menu-14d',
    minBytes: 80000,
    path: '/v1/canteens/perf-canteen-1/menu?locale=de&from=2026-03-02&to=2026-03-15',
    tier: 'primary',
  },
  { name: 'timetable-status', minBytes: 200, path: '/v1/timetable/status', tier: 'app-start' },
  {
    name: 'timetable-groups',
    minBytes: 25000,
    path: '/v1/timetable/groups?locale=de',
    tier: 'secondary',
  },
  {
    name: 'timetable-groups-search',
    minBytes: 9000,
    path: '/v1/timetable/groups?locale=de&query=PG1',
    tier: 'secondary',
  },
  { name: 'calendars-list', minBytes: 3500, path: '/v1/calendars?locale=de', tier: 'app-start' },
  {
    name: 'calendar-events-single-30d',
    minBytes: 15000,
    path: '/v1/calendars/perf-calendar-00/events?from=2026-03-02&to=2026-04-01',
    tier: 'primary',
  },
  {
    name: 'posts-list-p1',
    minBytes: 90000,
    path: '/v1/posts?locale=de&page=1&pageSize=20',
    tier: 'primary',
  },
  {
    name: 'posts-channels',
    minBytes: 1200,
    path: '/v1/posts/channels?locale=de',
    tier: 'app-start',
  },
  { name: 'posts-tags', minBytes: 800, path: '/v1/posts/tags?locale=de', tier: 'secondary' },
  {
    name: 'posts-detail',
    minBytes: 4500,
    path: '/v1/posts/perf-post-0?locale=de',
    tier: 'primary',
  },
  {
    name: 'posts-events',
    minBytes: 90000,
    path: '/v1/posts/events?locale=de&page=1&pageSize=20',
    tier: 'primary',
  },
  { name: 'contact-areas', minBytes: 3000, path: '/v1/contact-areas?locale=de', tier: 'secondary' },
  { name: 'rooms-list', minBytes: 12000, path: '/v1/rooms?locale=de', tier: 'secondary' },
];

/**
 * Aggregated calendar events across N calendars — built here rather than
 * hardcoded, because the calendar count is the variable this route is
 * sensitive to.
 */
function aggregatedRoute(calendarCount, days) {
  const slugs = Array.from(
    { length: calendarCount },
    (_, i) => `perf-calendar-${String(i).padStart(2, '0')}`,
  );
  const to = new Date(Date.UTC(2026, 2, 2) + days * 86_400_000).toISOString().slice(0, 10);
  return {
    name: `calendar-events-agg-${calendarCount}x${days}d`,
    // Scales with the calendars asked for, so the floor does too. Deliberately
    // an order of magnitude under the measured size — this catches a route
    // that stopped returning anything, not one that got a little smaller.
    minBytes: calendarCount * 2_000,
    path: `/v1/calendars/events?from=2026-03-02&to=${to}&${slugs
      .map((s) => `calendar=${s}`)
      .join('&')}`,
    tier: 'primary',
  };
}

function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  // Nearest-rank: the reported value is always an observed one.
  const rank = Math.max(1, Math.ceil((p / 100) * sorted.length));
  return sorted[rank - 1];
}

async function timedRequest(url) {
  const started = process.hrtime.bigint();
  const response = await fetch(url, {
    // Compression is enabled in main.ts. Announcing gzip is what a real client
    // does, so the measurement includes the compression work rather than
    // hiding it behind an identity response.
    headers: { 'accept-encoding': 'gzip, br', accept: 'application/json' },
  });
  const body = await response.arrayBuffer();
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;
  return { elapsedMs, status: response.status, bytes: body.byteLength };
}

async function measureRoute(route) {
  const url = `${baseUrl}${route.path}`;

  // Cold first: before any warmup touches this route.
  const cold = await timedRequest(url);

  for (let i = 0; i < warmup; i += 1) await timedRequest(url);

  const samples = [];
  let status = cold.status;
  let bytes = cold.bytes;
  for (let i = 0; i < iterations; i += 1) {
    const result = await timedRequest(url);
    samples.push(result.elapsedMs);
    status = result.status;
    bytes = result.bytes;
  }
  samples.sort((a, b) => a - b);

  return {
    name: route.name,
    tier: route.tier,
    path: route.path,
    status,
    responseBytes: bytes,
    coldMs: Number(cold.elapsedMs.toFixed(2)),
    p50Ms: Number(percentile(samples, 50).toFixed(2)),
    p90Ms: Number(percentile(samples, 90).toFixed(2)),
    p95Ms: Number(percentile(samples, 95).toFixed(2)),
    p99Ms: Number(percentile(samples, 99).toFixed(2)),
    maxMs: Number(samples[samples.length - 1].toFixed(2)),
  };
}

async function main() {
  const routes = [
    ...ROUTES,
    aggregatedRoute(3, 30),
    aggregatedRoute(12, 30),
    aggregatedRoute(12, 120),
  ];

  const results = [];
  /**
   * Routes that answered, but with far less than they are supposed to hold.
   *
   * A route measured empty is the worst kind of result this harness can
   * produce, because it looks like the best one. `/v1/rooms` did exactly that
   * between the baseline and LEVIORA-185: the room model moved its technical
   * data into the bundled catalogue, the stub kept inventing roomKeys that are
   * in no catalogue, every row was dropped, and the route went from 107.7 kB
   * to 93 bytes. Its p95 duly "improved" from 9.91 ms to 1.68 ms and two
   * acceptance runs recorded it as green.
   *
   * `minBytes` is a floor, not an expected size: payloads legitimately shrink
   * when an editorial field is dropped, and this must not fire on that. It
   * fires when a route has effectively stopped answering — and then the run
   * fails loudly instead of publishing a flattering number.
   */
  const collapsed = [];
  for (const route of routes) {
    const result = await measureRoute(route);
    results.push(result);
    const floor = route.minBytes ?? 0;
    const short = result.responseBytes < floor;
    if (short) collapsed.push({ ...result, minBytes: floor });
    process.stdout.write(
      `${result.name.padEnd(34)} status=${result.status} cold=${String(result.coldMs).padStart(8)}ms ` +
        `p50=${String(result.p50Ms).padStart(7)}ms p95=${String(result.p95Ms).padStart(7)}ms ` +
        `max=${String(result.maxMs).padStart(7)}ms bytes=${result.responseBytes}` +
        `${short ? `  <-- BELOW FLOOR (${floor} B)` : ''}\n`,
    );
  }

  const report = {
    label,
    iterations,
    warmup,
    baseUrl,
    node: process.version,
    results,
  };

  if (outFile) {
    mkdirSync(dirname(outFile), { recursive: true });
    writeFileSync(outFile, `${JSON.stringify(report, null, 2)}\n`);
    process.stdout.write(`\nWrote ${outFile}\n`);
  }

  // Written first, then failed: the numbers stay available for diagnosis, but
  // the run does not read as a successful measurement.
  if (collapsed.length > 0) {
    process.stderr.write(
      `\n${collapsed.length} route(s) answered with far less than they should. ` +
        'These numbers do not measure the route and must not be compared with a baseline:\n',
    );
    for (const route of collapsed) {
      process.stderr.write(
        `  ${route.name}: ${route.responseBytes} B, floor ${route.minBytes} B (${route.path})\n`,
      );
    }
    process.stderr.write(
      'Check the seeded profile and scripts/perf/strapi-stub.mjs before trusting this run.\n',
    );
    process.exitCode = 1;
  }
}

await main();
