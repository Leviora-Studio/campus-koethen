import { Inject, Injectable, Logger } from '@nestjs/common';
import { BodyTooLargeError, readBoundedBytes } from '../../common/http/bounded-body';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { parseIfNoneMatch } from './media.conditional';
import { isAllowedMediaType, normaliseMediaPath } from './media.path';

export interface MediaFile {
  kind: 'file';
  body: Buffer;
  contentType: string;
  /** Strapi's own validator, forwarded so clients can revalidate cheaply. */
  etag: string | null;
}

/**
 * The upstream confirmed the client's copy is still current. No image bytes
 * were sent, and none were read.
 */
export interface MediaNotModified {
  kind: 'not-modified';
  etag: string | null;
}

export type MediaResult = MediaFile | MediaNotModified;

export type MediaFailure = 'not-found' | 'unsupported' | 'too-large' | 'unavailable';

export class MediaError extends Error {
  constructor(public readonly kind: MediaFailure) {
    super(kind);
    this.name = 'MediaError';
  }
}

/**
 * Reads one editorial image from Strapi's upload directory.
 *
 * Why this exists at all: the app must not talk to Strapi (AGENTS.md §2.1), and
 * Strapi's local provider publishes **relative** URLs, which are useless to a
 * mobile client. So the Campus API serves the bytes itself and publishes its
 * own URL. Strapi's address stays configuration and never reaches a payload.
 *
 * It is deliberately narrow: images only, one directory only, a hard size
 * limit, no redirects. A general-purpose file proxy would be a much larger
 * thing to defend.
 *
 * Conditional requests are passed through end to end. Without that, a client
 * revalidating a photo it already holds still costs a full download from Strapi
 * into this process's heap — up to {@link MediaService.maxBytes} of it — only
 * for the result to be recognised as unchanged and thrown away. This is the
 * most expensive route of the API in bytes, so the validator is forwarded and
 * an upstream 304 is answered as a 304.
 */
@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private readonly baseUrl: string;

  /** An editorial image far above this is a mistake, not a photo. */
  static readonly maxBytes = 12 * 1024 * 1024;

  constructor(@Inject(ENV) private readonly env: Env) {
    this.baseUrl = env.STRAPI_BASE_URL.replace(/\/+$/, '');
  }

  /**
   * Fetches one image, revalidating instead of re-downloading when the client
   * already has a copy.
   *
   * The endpoint has always handed out Strapi's ETag; without this it never
   * accepted one back, so a revalidating client pulled the full image through
   * this process every time — the most expensive path in the API measured in
   * bytes.
   */
  async fetch(path: string, options: { ifNoneMatch?: string | null } = {}): Promise<MediaResult> {
    const safe = normaliseMediaPath(path);
    if (safe === null) {
      // Refused before any request is made: the target of a server-side fetch
      // must never be decided by the caller.
      throw new MediaError('not-found');
    }

    // Parsing lives in media.conditional.ts: it is a pure grammar decision, it
    // is tested exhaustively there, and its entity-tag rule admits only visible
    // ASCII — so a forwarded value cannot carry a CR, LF or NUL and cannot
    // smuggle a second header onto the outgoing request.
    const validator = parseIfNoneMatch(options.ifNoneMatch);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.env.STRAPI_TIMEOUT_MS);

    try {
      const response = await fetch(`${this.baseUrl}${safe}`, {
        method: 'GET',
        signal: controller.signal,
        // A redirect could point anywhere; the upload directory has no reason
        // to issue one.
        redirect: 'error',
        headers: {
          Accept: 'image/*',
          ...(validator === null ? {} : { 'If-None-Match': validator.header }),
        },
      });

      // Checked before `response.ok`, which is false for a 304. Nothing else
      // is inspected: a 304 carries no content type and no body, so the type
      // and size guards below have nothing to guard. Only honoured when we
      // actually asked conditionally — an unsolicited 304 is a broken upstream,
      // not an answer.
      if (validator !== null && response.status === 304) {
        // RFC 9110 §15.4.5 says a 304 SHOULD carry the validator. When it does
        // not, the client's own tag stands in — but only when it named exactly
        // one, since echoing a whole list as an ETag would be nonsense.
        return { kind: 'not-modified', etag: response.headers.get('etag') ?? validator.sole };
      }

      if (response.status === 404) {
        throw new MediaError('not-found');
      }
      if (!response.ok) {
        throw new MediaError('unavailable');
      }

      const contentType = response.headers.get('content-type');
      if (!isAllowedMediaType(contentType)) {
        throw new MediaError('unsupported');
      }

      const declared = Number(response.headers.get('content-length') ?? '0');
      if (Number.isFinite(declared) && declared > MediaService.maxBytes) {
        throw new MediaError('too-large');
      }

      // The header above is a claim; the bytes are the fact. Counted WHILE
      // reading, so a missing or dishonest Content-Length cannot make this
      // process buffer more than the limit before anything refuses it.
      const body = await readBoundedBytes(response, MediaService.maxBytes);

      return {
        kind: 'file',
        body,
        contentType: contentType as string,
        etag: response.headers.get('etag'),
      };
    } catch (error) {
      if (error instanceof MediaError) {
        throw error;
      }
      if (error instanceof BodyTooLargeError) {
        throw new MediaError('too-large');
      }
      // The path is logged, never a token and never the upstream address.
      this.logger.warn(`Media fetch failed (${safe})`);
      throw new MediaError('unavailable');
    } finally {
      clearTimeout(timer);
    }
  }
}
