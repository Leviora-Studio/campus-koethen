/**
 * Google public-calendar URL handling — the security core of the feature.
 *
 * Two jobs, both pure and dependency-free:
 *
 *  1. Extract the calendar id from an editor-pasted PUBLIC share link. The share
 *     link is untrusted input: it is validated exhaustively (scheme, host,
 *     userinfo, port, path, single cid, base64, UTF-8, length, control chars)
 *     and only the decoded calendar id is ever used downstream.
 *
 *  2. Construct the fixed URLs the backend actually talks to / hands to the app.
 *     The ICS feed URL is built here from a FIXED scheme + host + path with the
 *     calendar id as a single percent-encoded path segment — the pasted share
 *     URL is never fetched, and no base URL ever comes from Strapi or the env.
 *
 * This prevents SSRF: nothing the editor types can redirect a request to another
 * host, a private feed, an internal IP, or a different scheme.
 */

export type ShareUrlErrorKind =
  | 'unparseable'
  | 'notHttps'
  | 'wrongHost'
  | 'userInfo'
  | 'hasPort'
  | 'badPath'
  | 'missingCid'
  | 'multipleCid'
  | 'cidTooLong'
  | 'cidNotBase64'
  | 'cidNotUtf8'
  | 'calendarIdTooLong'
  | 'calendarIdUnsafeChars';

export class InvalidShareUrlError extends Error {
  constructor(public readonly kind: ShareUrlErrorKind) {
    super(`Invalid Google calendar share URL: ${kind}`);
    this.name = 'InvalidShareUrlError';
  }
}

/** The one and only host the token and calendar ids may ever reach. */
export const GOOGLE_CALENDAR_HOST = 'calendar.google.com';
export const MAX_SHARE_URL_LENGTH = 2048;
export const MAX_CID_LENGTH = 1024;
export const MAX_CALENDAR_ID_LENGTH = 256;
export const DEFAULT_TIME_ZONE = 'Europe/Berlin';

/** Exactly the public share paths Google uses; nothing else. */
const ALLOWED_SHARE_PATH = /^\/calendar\/(?:render|u\/\d{1,3}(?:\/r)?)$/;

/** A conservative IANA-name shape. Not a full tz database, just anti-injection. */
const TIME_ZONE_PATTERN = /^[A-Za-z][A-Za-z0-9_+-]*(?:\/[A-Za-z0-9_+-]+){0,2}$/;

/** Base64 / base64url alphabet with optional `=` padding. */
const BASE64_PATTERN = /^[A-Za-z0-9+/_-]+={0,2}$/;

export type ExtractResult =
  { ok: true; calendarId: string } | { ok: false; kind: ShareUrlErrorKind };

/** Non-throwing variant, convenient for validation call sites. */
export function tryExtractCalendarId(shareUrl: string): ExtractResult {
  try {
    return { ok: true, calendarId: extractCalendarId(shareUrl) };
  } catch (error) {
    if (error instanceof InvalidShareUrlError) {
      return { ok: false, kind: error.kind };
    }
    return { ok: false, kind: 'unparseable' };
  }
}

/**
 * Extracts and validates the calendar id from a public Google share URL.
 * Throws {@link InvalidShareUrlError} with a specific `kind` on any violation.
 */
export function extractCalendarId(shareUrl: string): string {
  if (
    typeof shareUrl !== 'string' ||
    shareUrl.length === 0 ||
    shareUrl.length > MAX_SHARE_URL_LENGTH
  ) {
    throw new InvalidShareUrlError('unparseable');
  }

  let url: URL;
  try {
    url = new URL(shareUrl);
  } catch {
    throw new InvalidShareUrlError('unparseable');
  }

  if (url.protocol !== 'https:') throw new InvalidShareUrlError('notHttps');
  // `hostname` excludes any port and is already lowercased + IDNA-normalised by
  // the URL parser, so a suffix/subdomain/parent-domain trick cannot match.
  if (url.hostname !== GOOGLE_CALENDAR_HOST) throw new InvalidShareUrlError('wrongHost');
  if (url.username !== '' || url.password !== '') throw new InvalidShareUrlError('userInfo');
  if (url.port !== '') throw new InvalidShareUrlError('hasPort');
  if (!ALLOWED_SHARE_PATH.test(url.pathname)) throw new InvalidShareUrlError('badPath');

  const cids = url.searchParams.getAll('cid');
  if (cids.length > 1) throw new InvalidShareUrlError('multipleCid');
  const cid = cids[0];
  if (cid === undefined || cid === '') throw new InvalidShareUrlError('missingCid');

  return decodeCalendarId(cid);
}

/** Decodes and hardens the base64/base64url `cid` value. */
function decodeCalendarId(cid: string): string {
  if (cid.length > MAX_CID_LENGTH) throw new InvalidShareUrlError('cidTooLong');
  if (!BASE64_PATTERN.test(cid)) throw new InvalidShareUrlError('cidNotBase64');

  // Normalise base64url -> base64, then decode.
  const normalised = cid.replace(/-/g, '+').replace(/_/g, '/');
  const decoded = Buffer.from(normalised, 'base64');
  if (decoded.length === 0) throw new InvalidShareUrlError('cidNotBase64');

  // Buffer's base64 decoder is lenient (it silently skips invalid characters).
  // Re-encode and compare (ignoring padding/url-alphabet differences) to reject
  // anything that was not genuine, canonical base64.
  const canonical = (s: string): string =>
    s.replace(/[=]+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
  if (canonical(decoded.toString('base64')) !== canonical(cid)) {
    throw new InvalidShareUrlError('cidNotBase64');
  }

  // Strict UTF-8: decoding then re-encoding must reproduce the exact bytes, so
  // invalid sequences (which toString would replace with U+FFFD) are rejected.
  const calendarId = decoded.toString('utf8');
  if (!Buffer.from(calendarId, 'utf8').equals(decoded)) {
    throw new InvalidShareUrlError('cidNotUtf8');
  }

  if (calendarId.length > MAX_CALENDAR_ID_LENGTH)
    throw new InvalidShareUrlError('calendarIdTooLong');

  // No control chars, NUL, newlines, or leading/trailing/embedded whitespace.
  // Real Google ids are e-mail-like: letters, digits and a small punctuation set.
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f]/.test(calendarId)) throw new InvalidShareUrlError('calendarIdUnsafeChars');
  if (/\s/.test(calendarId)) throw new InvalidShareUrlError('calendarIdUnsafeChars');
  if (calendarId.trim() !== calendarId) throw new InvalidShareUrlError('calendarIdUnsafeChars');

  return calendarId;
}

/**
 * The FIXED public ICS feed URL. The only URL the worker ever downloads.
 *
 * Scheme, host and path prefix/suffix are constant; the calendar id is a single
 * `encodeURIComponent` path segment, so `@`, `#`, `/` and every other character
 * are percent-encoded and can never introduce a second segment or traversal.
 */
export function buildIcsFeedUrl(calendarId: string): string {
  return `https://${GOOGLE_CALENDAR_HOST}/calendar/ical/${encodeURIComponent(calendarId)}/public/basic.ics`;
}

/** The "open a single calendar in Google" link handed to the app. */
export function buildSingleOpenUrl(calendarId: string): string {
  const cid = Buffer.from(calendarId, 'utf8').toString('base64url');
  const url = new URL(`https://${GOOGLE_CALENDAR_HOST}/calendar/render`);
  url.searchParams.set('cid', cid);
  return url.toString();
}

export function isValidTimeZone(timeZone: string): boolean {
  return (
    typeof timeZone === 'string' &&
    timeZone.length > 0 &&
    timeZone.length <= 64 &&
    TIME_ZONE_PATTERN.test(timeZone)
  );
}

/**
 * The combined "open selected calendars in Google" embed view. One `src` per
 * calendar id (URL-encoded), plus a validated `ctz`. This is a shared VIEW only;
 * it never adds anything to a user's personal Google account.
 */
export function buildCombinedEmbedUrl(
  calendarIds: string[],
  timeZone: string = DEFAULT_TIME_ZONE,
): string {
  if (!Array.isArray(calendarIds) || calendarIds.length === 0) {
    throw new Error('buildCombinedEmbedUrl requires at least one calendar id');
  }
  if (!isValidTimeZone(timeZone)) {
    throw new Error(`Unsafe time zone: ${timeZone}`);
  }
  const url = new URL(`https://${GOOGLE_CALENDAR_HOST}/calendar/embed`);
  for (const id of calendarIds) {
    url.searchParams.append('src', id);
  }
  url.searchParams.set('ctz', timeZone);
  return url.toString();
}
