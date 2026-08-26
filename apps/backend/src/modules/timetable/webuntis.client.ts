import { Inject, Injectable, Logger } from '@nestjs/common';
import { BodyTooLargeError, readBoundedText } from '../../common/http/bounded-body';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import {
  AppData,
  EntriesResponse,
  FilterResponse,
  appDataSchema,
  entriesResponseSchema,
  filterResponseSchema,
} from './webuntis.schema';

/**
 * The ONLY place that talks to WebUntis.
 *
 * Everything upstream-specific stops here: the base URL, the anonymous school
 * header, the dynamic school year header and the raw payload shapes. Nothing
 * above this layer — and certainly nothing in the app — learns that WebUntis
 * exists beyond the name shown to users.
 *
 * The source is an internal interface of a third party's web UI. It is treated
 * as hostile input throughout: status checked, content type checked, size
 * bounded, body schema-validated, and errors reduced to a classification with
 * no upstream detail attached.
 */

export type WebUntisErrorKind =
  'disabled' | 'timeout' | 'network' | 'http' | 'rate_limited' | 'html' | 'malformed';

export class WebUntisError extends Error {
  /** Honoured from a `Retry-After` header when upstream supplies one. */
  retryAfterMs?: number;

  constructor(
    public readonly kind: WebUntisErrorKind,
    /**
     * Deliberately generic. It is logged and stored in sync runs, so it must
     * never carry the host, a header, a raw body or a person's name.
     */
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'WebUntisError';
  }
}

@Injectable()
export class WebUntisClient {
  private readonly logger = new Logger(WebUntisClient.name);
  private readonly baseUrl: string;
  private lastRequestAt = 0;

  constructor(@Inject(ENV) private readonly env: Env) {
    this.baseUrl = env.WEBUNTIS_BASE_URL.replace(/\/+$/, '');
  }

  get isEnabled(): boolean {
    return this.env.WEBUNTIS_ENABLED;
  }

  /** School year context. The id it returns is required by every other call. */
  async fetchAppData(): Promise<AppData> {
    return this.get('/app/data', {}, appDataSchema, null);
  }

  /** Full class catalogue. ~270 entries at the time of writing. */
  async fetchClasses(schoolYearId: number): Promise<FilterResponse> {
    return this.get(
      '/timetable/filter',
      { resourceType: 'CLASS' },
      filterResponseSchema,
      schoolYearId,
    );
  }

  /**
   * Entries for EVERY class in the given window.
   *
   * Deliberately sends no resource ids: upstream then returns all classes in a
   * single response (270 classes x 5 days ≈ 505 KB in ~1.2 s when measured).
   * That is what keeps this feature to a couple of requests per sync instead of
   * hammering a third party 270 times.
   */
  async fetchEntries(schoolYearId: number, from: string, to: string): Promise<EntriesResponse> {
    return this.get(
      '/timetable/entries',
      { start: from, end: to, format: '2', resourceType: 'CLASS' },
      entriesResponseSchema,
      schoolYearId,
    );
  }

  private buildHeaders(schoolYearId: number | null): Record<string, string> {
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'anonymous-school': this.env.WEBUNTIS_ANONYMOUS_SCHOOL,
    };
    // Only sent once a context is actually known; guessing an id would produce
    // confusing upstream errors.
    if (schoolYearId !== null) {
      headers['X-Webuntis-Api-School-Year-Id'] = String(schoolYearId);
    }
    return headers;
  }

  /** Keeps a polite distance between consecutive upstream requests. */
  private async throttle(): Promise<void> {
    const spacing = this.env.WEBUNTIS_REQUEST_SPACING_MS;
    if (spacing <= 0) {
      return;
    }
    const wait = this.lastRequestAt + spacing - Date.now();
    if (wait > 0) {
      await new Promise((resolve) => setTimeout(resolve, wait));
    }
    this.lastRequestAt = Date.now();
  }

  private async get<T>(
    path: string,
    query: Record<string, string>,
    schema: { safeParse: (value: unknown) => { success: boolean; data?: unknown } },
    schoolYearId: number | null,
  ): Promise<T> {
    if (!this.env.WEBUNTIS_ENABLED) {
      throw new WebUntisError(
        'disabled',
        'The timetable integration is disabled by configuration.',
      );
    }

    const url = `${this.baseUrl}${path}${
      Object.keys(query).length > 0 ? `?${new URLSearchParams(query).toString()}` : ''
    }`;
    const attempts = this.env.WEBUNTIS_RETRY_ATTEMPTS + 1;
    let lastError = new WebUntisError('network', 'The timetable source was never contacted.');
    let made = 0;

    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      made = attempt;
      await this.throttle();

      try {
        return (await this.attempt(url, schoolYearId, schema)) as T;
      } catch (error) {
        lastError =
          error instanceof WebUntisError
            ? error
            : new WebUntisError('network', 'unexpected transport failure');

        const retryable =
          lastError.kind === 'timeout' ||
          lastError.kind === 'network' ||
          lastError.kind === 'rate_limited' ||
          (lastError.kind === 'http' && (lastError.status ?? 500) >= 500);

        if (!retryable || attempt === attempts) {
          break;
        }

        // Exponential backoff with a little jitter so repeated failures from
        // several jobs do not line up into a synchronised burst.
        const backoff = 500 * 2 ** (attempt - 1) + Math.floor(Math.random() * 250);
        const delay = lastError.retryAfterMs ?? backoff;
        this.logger.warn(
          `Timetable source attempt ${attempt}/${attempts} failed (${lastError.kind}); retrying in ${delay}ms`,
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }

    // Path only, never the full URL: the host is upstream detail.
    // `made`, not `attempts`: a non-retryable failure stops at the first try,
    // and claiming three would send the next reader hunting for retries that
    // never happened.
    this.logger.warn(
      `Timetable source request failed after ${made} attempt(s): ${lastError.kind} (${path})`,
    );
    throw lastError;
  }

  private async attempt(
    url: string,
    schoolYearId: number | null,
    schema: { safeParse: (value: unknown) => { success: boolean; data?: unknown } },
  ): Promise<unknown> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.env.WEBUNTIS_HTTP_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
        headers: this.buildHeaders(schoolYearId),
        // A third-party response must not turn this configured outbound call
        // into an SSRF hop to an arbitrary second host.
        redirect: 'error',
      });

      if (response.status === 429) {
        const retryAfter = Number(response.headers.get('retry-after'));
        const error = new WebUntisError(
          'rate_limited',
          'The timetable source is rate limiting us.',
          429,
        );
        if (Number.isFinite(retryAfter) && retryAfter > 0) {
          error.retryAfterMs = Math.min(retryAfter * 1000, 60_000);
        }
        throw error;
      }

      if (!response.ok) {
        throw new WebUntisError(
          'http',
          `The timetable source answered with status ${response.status}.`,
          response.status,
        );
      }

      // A login or error PAGE is the classic failure here: HTTP 200 with HTML.
      // Parsing it would produce a confusing schema error instead of the real
      // diagnosis, which is that the anonymous context was rejected.
      const contentType = response.headers.get('content-type') ?? '';
      if (!contentType.toLowerCase().includes('json')) {
        throw new WebUntisError(
          'html',
          'The timetable source returned a non-JSON page where JSON was expected.',
        );
      }

      const declaredLength = Number(response.headers.get('content-length'));
      if (
        Number.isFinite(declaredLength) &&
        declaredLength > this.env.WEBUNTIS_MAX_RESPONSE_BYTES
      ) {
        throw new WebUntisError(
          'malformed',
          'The timetable source response exceeded the size limit.',
        );
      }

      // Bounded WHILE reading. The declared length above is only a claim and is
      // often absent; without a streamed cap the body would already be in
      // memory by the time anything refused it.
      let text: string;
      try {
        text = await readBoundedText(response, this.env.WEBUNTIS_MAX_RESPONSE_BYTES);
      } catch (error) {
        if (error instanceof BodyTooLargeError) {
          throw new WebUntisError(
            'malformed',
            'The timetable source response exceeded the size limit.',
          );
        }
        throw error;
      }

      let payload: unknown;
      try {
        payload = JSON.parse(text);
      } catch {
        throw new WebUntisError('malformed', 'The timetable source returned unparseable JSON.');
      }

      const parsed = schema.safeParse(payload);
      if (!parsed.success) {
        // The issues are NOT attached: they quote the offending payload, which
        // can contain teacher names.
        throw new WebUntisError('malformed', 'The timetable source response failed validation.');
      }

      return parsed.data;
    } catch (error) {
      if (error instanceof WebUntisError) {
        throw error;
      }
      if (error instanceof Error && error.name === 'AbortError') {
        throw new WebUntisError('timeout', 'The timetable source request timed out.');
      }
      throw new WebUntisError('network', 'The timetable source is unreachable.');
    } finally {
      clearTimeout(timer);
    }
  }
}
