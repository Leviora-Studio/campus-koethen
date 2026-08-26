import { Inject, Injectable, Logger } from '@nestjs/common';
import { BodyTooLargeError, readBoundedText } from '../../common/http/bounded-body';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';

/**
 * The ONLY way this codebase talks to Strapi.
 *
 * Architectural boundary (docs/architecture.md, G2): editorial content is read
 * over Strapi's REST API with a server-side read-only token. There is no direct
 * database access to Strapi's tables and no shared Prisma connection.
 *
 * The base URL is never a source constant — it comes from STRAPI_BASE_URL, so
 * switching DEV/PROD is purely an environment change.
 */

export type StrapiErrorKind = 'timeout' | 'unauthorized' | 'unavailable' | 'malformed';

export class StrapiRequestError extends Error {
  constructor(
    public readonly kind: StrapiErrorKind,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'StrapiRequestError';
  }
}

/** Strapi 5 list response. Deliberately kept internal to this module. */
export interface StrapiListResponse<T> {
  data: T[];
  meta?: {
    pagination?: { page: number; pageSize: number; pageCount: number; total: number };
  };
}

/**
 * Strapi's query syntax nests arbitrarily — `$and` and `$or` take arrays of
 * filter objects — so the value type stays open and the encoder handles the
 * shapes structurally.
 */
export type StrapiQuery = Record<string, unknown>;

/**
 * Stringifies a query leaf. Objects and arrays are handled structurally by
 * the encoder before reaching here, so anything left is a primitive; this
 * keeps an accidental object from being serialised as '[object Object]'.
 */
function stringifyPrimitive(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return '';
}

@Injectable()
export class StrapiClient {
  private readonly logger = new Logger(StrapiClient.name);
  private readonly baseUrl: string;

  /**
   * Largest editorial payload this client will buffer.
   *
   * Every other upstream client in this codebase declares a byte limit and
   * enforces it WHILE reading (see common/http/bounded-body.ts); this one used
   * `response.json()`, which has no bound at all — the only limit left was the
   * memory the process happens to have. The CMS is our own service, but it sits
   * behind a URL that comes from the environment and it is reached over plain
   * HTTP inside the deployment network, so "it is trusted" is a statement about
   * intent rather than about what can arrive on the socket.
   *
   * The bound is generous on purpose: `pageSize` is capped at 50 and the room
   * catalogue is small, so the largest real answer is orders of magnitude below
   * this. Anything above it is a fault, not a page of posts.
   */
  static readonly maxResponseBytes = 16 * 1024 * 1024;

  constructor(@Inject(ENV) private readonly env: Env) {
    // Normalise once so callers never worry about a trailing slash.
    this.baseUrl = env.STRAPI_BASE_URL.replace(/\/+$/, '');
  }

  get isConfigured(): boolean {
    return this.env.STRAPI_API_TOKEN.length > 0;
  }

  /**
   * Flattens a nested query object into Strapi's bracket syntax,
   * e.g. `{ filters: { slug: { $eq: 'x' } } }` -> `filters[slug][$eq]=x`.
   */
  private static encodeQuery(query: StrapiQuery, prefix = ''): string[] {
    const parts: string[] = [];

    for (const [key, value] of Object.entries(query)) {
      if (value === undefined) {
        continue;
      }
      const path = prefix ? `${prefix}[${key}]` : key;

      if (Array.isArray(value)) {
        value.forEach((entry, index) => {
          const indexedPath = `${path}[${index}]`;
          if (entry !== null && typeof entry === 'object') {
            // e.g. filters[$and][0][validFrom][$null]=true
            parts.push(...StrapiClient.encodeQuery(entry as StrapiQuery, indexedPath));
          } else {
            parts.push(`${encodeURIComponent(indexedPath)}=${encodeURIComponent(String(entry))}`);
          }
        });
      } else if (value !== null && typeof value === 'object') {
        parts.push(...StrapiClient.encodeQuery(value as StrapiQuery, path));
      } else {
        parts.push(`${encodeURIComponent(path)}=${encodeURIComponent(stringifyPrimitive(value))}`);
      }
    }

    return parts;
  }

  private buildUrl(path: string, query?: StrapiQuery): string {
    const normalisedPath = path.startsWith('/') ? path : `/${path}`;
    const queryString = query ? StrapiClient.encodeQuery(query).join('&') : '';
    return `${this.baseUrl}${normalisedPath}${queryString ? `?${queryString}` : ''}`;
  }

  /**
   * Performs a GET with a hard timeout and bounded retries.
   *
   * Only transport failures and 5xx responses are retried; a 4xx is a
   * deterministic answer and retrying it would just add load.
   */
  async get<T>(path: string, query?: StrapiQuery): Promise<T> {
    const url = this.buildUrl(path, query);
    const attempts = this.env.STRAPI_RETRY_ATTEMPTS + 1;

    let lastError: StrapiRequestError = new StrapiRequestError(
      'unavailable',
      'Strapi request was never attempted',
    );

    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.env.STRAPI_TIMEOUT_MS);

      try {
        const response = await fetch(url, {
          method: 'GET',
          signal: controller.signal,
          headers: {
            Accept: 'application/json',
            ...(this.isConfigured ? { Authorization: `Bearer ${this.env.STRAPI_API_TOKEN}` } : {}),
          },
          // Same stance the media path already takes towards this very
          // upstream: a redirect could point anywhere, and STRAPI_BASE_URL —
          // not the CMS's answer — decides which host this token is sent to.
          redirect: 'error',
        });

        if (response.status === 401 || response.status === 403) {
          // Not retryable and a real operational problem — the token is missing
          // or lacks the read scope.
          throw new StrapiRequestError(
            'unauthorized',
            'Strapi rejected the read-only token',
            response.status,
          );
        }

        if (!response.ok) {
          throw new StrapiRequestError(
            'unavailable',
            `Strapi responded with status ${response.status}`,
            response.status,
          );
        }

        // Read with the cap enforced as the bytes arrive, then parse. A limit
        // checked after `response.json()` would not be a limit: by then the
        // whole body is already on the heap.
        let body: string;
        try {
          body = await readBoundedText(response, StrapiClient.maxResponseBytes);
        } catch (error) {
          if (error instanceof BodyTooLargeError) {
            throw new StrapiRequestError('malformed', 'Strapi returned an oversized body');
          }
          throw error;
        }

        try {
          return JSON.parse(body) as T;
        } catch {
          throw new StrapiRequestError('malformed', 'Strapi returned a non-JSON body');
        }
      } catch (error) {
        lastError = this.toStrapiError(error);

        const retryable = lastError.kind === 'timeout' || lastError.kind === 'unavailable';
        if (!retryable || attempt === attempts) {
          break;
        }

        // Exponential backoff: 200ms, 400ms, 800ms …
        await new Promise((resolve) => setTimeout(resolve, 200 * 2 ** (attempt - 1)));
      } finally {
        clearTimeout(timer);
      }
    }

    // The URL is logged without query values and never with the token.
    this.logger.warn(
      `Strapi request failed after ${attempts} attempt(s): ${lastError.kind} (${path})`,
    );
    throw lastError;
  }

  private toStrapiError(error: unknown): StrapiRequestError {
    if (error instanceof StrapiRequestError) {
      return error;
    }
    if (error instanceof Error && error.name === 'AbortError') {
      return new StrapiRequestError('timeout', 'Strapi request timed out');
    }
    return new StrapiRequestError('unavailable', 'Strapi is unreachable');
  }

  /** Bounded connectivity probe used by /health/ready. */
  async probe(timeoutMs: number): Promise<void> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`${this.baseUrl}/_health`, {
        method: 'GET',
        signal: controller.signal,
        // Same reason as the read path above, and it was missed here at first:
        // following a redirect would let the answer decide which host actually
        // reports "ready". /health/ready would then call Strapi healthy on the
        // strength of a 200 from somewhere else entirely.
        redirect: 'error',
      });
      if (!response.ok) {
        throw new StrapiRequestError(
          'unavailable',
          `Strapi health endpoint returned ${response.status}`,
          response.status,
        );
      }
    } catch (error) {
      throw this.toStrapiError(error);
    } finally {
      clearTimeout(timer);
    }
  }
}
