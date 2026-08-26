/**
 * What a client's `If-None-Match` may look like, and what is forwarded upstream.
 *
 * The media endpoint hands this header to a server-side `fetch`. That makes it
 * caller-controlled input on an outbound request, so it is validated the same
 * way the path is: an allowlist of exactly the grammar RFC 9110 §8.8.3 defines,
 * bounded in length, refused rather than repaired when it does not fit.
 *
 * Refusing means "do not forward" — never "fail the request". A client that
 * sends nonsense gets the image, exactly as it did before this header was ever
 * read. The header only ever decides whether the upstream request is
 * conditional; the upstream ADDRESS stays settled by media.path.ts alone.
 *
 * Kept as a pure function so the decisions can be tested exhaustively without a
 * running Strapi or a HTTP layer.
 */

/**
 * Far more than the single short validator this API ever issues, and small
 * enough that a client cannot use the header as a channel for bulk data.
 */
const MAX_LENGTH = 256;

/**
 * `entity-tag = [ "W/" ] DQUOTE *etagc DQUOTE`, with
 * `etagc = %x21 / %x23-7E` — visible ASCII without the quote itself.
 *
 * Because nothing outside that set survives, a forwarded value can carry no
 * CR, LF or NUL, and therefore cannot smuggle a second header upstream.
 */
const ENTITY_TAG = /^(?:W\/)?"[\x21\x23-\x7E]*"$/;

export interface ClientValidator {
  /** The normalised value to forward as `If-None-Match`. */
  header: string;
  /** The entity-tag it names, when it names exactly one. */
  sole: string | null;
}

/**
 * Reads a client's `If-None-Match`, or `null` when it must not be forwarded.
 *
 * Accepts what a conformant client actually sends back: `*`, or a list of the
 * entity-tags it already holds. Everything else — an unquoted token, a control
 * character, a value longer than {@link MAX_LENGTH}, a non-string — is refused,
 * which simply means the upstream request stays unconditional.
 */
export function parseIfNoneMatch(value: unknown): ClientValidator | null {
  if (typeof value !== 'string') {
    return null;
  }
  const raw = value.trim();
  if (raw.length === 0 || raw.length > MAX_LENGTH) {
    return null;
  }
  if (raw === '*') {
    // Matches any current representation, so it names no single tag to echo.
    return { header: '*', sole: null };
  }

  const tags = raw.split(',').map((tag) => tag.trim());
  if (!tags.every((tag) => ENTITY_TAG.test(tag))) {
    return null;
  }
  return { header: tags.join(', '), sole: tags.length === 1 ? (tags[0] as string) : null };
}
