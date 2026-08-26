/**
 * What may be fetched through the media endpoint, and what may not.
 *
 * The endpoint takes a path that ultimately came from Strapi and hands it to
 * `fetch`. That is a server-side request whose target is influenced by input,
 * so the rule is an allowlist, not a blocklist: only files below Strapi's
 * upload directory, nothing else, ever.
 *
 * Kept as a pure function so the decisions can be tested exhaustively without
 * a running Strapi or a HTTP layer.
 */

/** Strapi's local upload provider serves everything under this prefix. */
const UPLOAD_PREFIX = '/uploads/';

/**
 * Filenames Strapi generates: name, hash, extension. Deliberately strict —
 * no directories, no percent-encoding, no whitespace.
 */
const SAFE_SEGMENT = /^[A-Za-z0-9._-]+$/;

/**
 * Normalises a Strapi media URL into the path this API will serve, or `null`
 * when it must not be served at all.
 *
 * Accepts what Strapi actually produces:
 *  - a relative path from the local provider (`/uploads/foo_abc123.png`);
 *  - an absolute URL from a remote provider, whose path is then taken.
 *
 * Refuses, in every case:
 *  - anything outside `/uploads/`;
 *  - `..` in any form, encoded or not — the classic traversal;
 *  - nested directories, query strings and fragments;
 *  - characters outside the conservative set above.
 */
export function normaliseMediaPath(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const raw = value.trim();
  if (raw.length === 0 || raw.length > 512) {
    return null;
  }

  let path: string;
  if (raw.startsWith('/')) {
    path = raw;
  } else {
    // A remote provider hands back an absolute URL. Only its path matters —
    // the host is decided by configuration, never by the payload.
    let parsed: URL;
    try {
      parsed = new URL(raw);
    } catch {
      return null;
    }
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
      return null;
    }
    path = parsed.pathname;
  }

  // A query or fragment would be carried into the upstream request.
  if (path.includes('?') || path.includes('#')) {
    return null;
  }

  // Decode once so an encoded traversal cannot slip past the checks below.
  // A path that does not decode cleanly is refused rather than guessed at.
  let decoded: string;
  try {
    decoded = decodeURIComponent(path);
  } catch {
    return null;
  }
  if (decoded !== path) {
    // Strapi's own filenames never need encoding. Anything that changes under
    // decoding was built to look like something it is not.
    return null;
  }

  if (!decoded.startsWith(UPLOAD_PREFIX)) {
    return null;
  }

  const filename = decoded.slice(UPLOAD_PREFIX.length);
  // One segment only: no subdirectories, and therefore no traversal.
  if (filename.length === 0 || !SAFE_SEGMENT.test(filename)) {
    return null;
  }
  if (filename === '.' || filename === '..') {
    return null;
  }

  return `${UPLOAD_PREFIX}${filename}`;
}

/**
 * The public URL this API publishes for a media file.
 *
 * Always relative: the client resolves it against the Campus API it is already
 * talking to. That keeps Strapi's address out of every public DTO — it is
 * configuration, not payload (AGENTS.md §2.4).
 */
export function publicMediaUrl(value: unknown): string | null {
  const path = normaliseMediaPath(value);
  return path === null ? null : `/v1/media${path}`;
}

/**
 * Media types this endpoint will pass through.
 *
 * Raster formats only. `image/svg+xml` is deliberately absent: an SVG is an
 * XML document that may carry `<script>` and event handlers, and this endpoint
 * answers with `Content-Disposition: inline`, so a browser would execute it on
 * this API's own origin. `nosniff` does not help — the content type would be
 * correct. Nothing is lost by refusing it: no client of this project renders
 * remote SVG (RemoteImage uses `Image.network`, whose codec has no SVG support;
 * `flutter_svg` is only ever used on bundled, versioned map assets).
 */
const ALLOWED_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/avif']);

/**
 * Whether an upstream content type may be forwarded.
 *
 * Raster images only. This endpoint exists so contact photos and news banners
 * can be shown; letting it serve arbitrary uploads would turn it into a general
 * file proxy for anything an editor ever put into the media library.
 */
export function isAllowedMediaType(value: string | null | undefined): boolean {
  if (!value) {
    return false;
  }
  const type = value.split(';', 1)[0]?.trim().toLowerCase() ?? '';
  return ALLOWED_TYPES.has(type);
}
