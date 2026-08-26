import compression from 'compression';
import type { Request, RequestHandler, Response } from 'express';

/**
 * Transport compression for the responses this API sends.
 *
 * The payloads that matter here are large and extremely repetitive: the
 * contact search index carries every area, person, description and room in one
 * response; the room catalogue repeats the same building and floor names
 * hundreds of times; a month of menus repeats the same markers and price
 * groups every day; a week of timetable entries repeats the same teachers and
 * rooms. JSON of that shape compresses by a factor of five to ten, and the
 * clients are phones on campus Wi-Fi or a mobile network.
 *
 * This is a TRANSPORT encoding and nothing else. The bytes a client ends up
 * with after decoding are the same bytes it would have received without it —
 * same DTOs, same `meta`, same order. A client that offers no encoding gets
 * the identical response it got before.
 *
 * Why a `Vary: Accept-Encoding` appears on JSON responses that were not
 * compressed: the answer for one client genuinely depends on that header, so a
 * shared cache has to key on it. Without the `Vary` a proxy could hand a
 * gzipped body to a client that never asked for one.
 *
 * On BREACH: compressing a response alongside reflected input is only a risk
 * when the response also carries a secret. This API has no authentication, no
 * cookies and no per-user data — every endpoint answers the same public
 * content to everyone (docs/api.md §1). There is nothing to extract.
 */

/**
 * Responses below this go out as they are.
 *
 * Under roughly a kilobyte the gzip framing, the extra header and the CPU on
 * both ends buy back close to nothing, and a payload that small is not what
 * made this worth doing. 1 KiB is the `compression` default; it is pinned here
 * so the tests and the documentation have one number to point at.
 */
export const COMPRESSION_THRESHOLD_BYTES = 1024;

/**
 * Decides whether a response is eligible at all.
 *
 * The explicit rule is images: `/v1/media/uploads/:filename` is the one
 * endpoint that answers with bytes rather than JSON, and its allowlist admits
 * PNG, JPEG, WebP, GIF and AVIF only — every one of them already compressed.
 * Running them through gzip burns CPU on both ends to produce a slightly
 * larger body.
 *
 * That refusal is written against the media type FAMILY rather than left to
 * `compressible`'s table, which would happily take `image/svg+xml`. What this
 * API serves as an image is decided by the media allowlist, and the answer to
 * "should this endpoint compress" should not move because a mime database
 * changed its mind.
 *
 * Everything else falls back to the default filter, so the eligible set stays
 * the well-understood one: JSON, text, the OpenAPI document, the docs page.
 */
export function shouldCompress(request: Request, response: Response): boolean {
  const contentType = response.getHeader('Content-Type');
  if (typeof contentType === 'string' && contentType.trim().toLowerCase().startsWith('image/')) {
    return false;
  }
  return compression.filter(request, response);
}

/**
 * The middleware, registered ahead of every route in `main.ts`.
 *
 * Negotiation is left to the library: Brotli when the client offers it, gzip
 * otherwise, and `identity` — no compression — whenever a client sends no
 * `Accept-Encoding` at all.
 */
export function createResponseCompression(): RequestHandler {
  return compression({
    threshold: COMPRESSION_THRESHOLD_BYTES,
    filter: shouldCompress,
  });
}
