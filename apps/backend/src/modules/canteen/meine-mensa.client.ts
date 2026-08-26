import { Inject, Injectable, Logger } from '@nestjs/common';
import { BodyTooLargeError, readBoundedText } from '../../common/http/bounded-body';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { FoodPlanResponse, foodPlanResponseSchema } from './meine-mensa.schema';

/**
 * HTTP client for the canteen source.
 *
 * Every response is schema-validated before it is returned, so an upstream
 * shape change becomes a clean, typed failure rather than corrupt data.
 */

export type CanteenSourceErrorKind = 'timeout' | 'http' | 'malformed' | 'network';

export class CanteenSourceError extends Error {
  constructor(
    public readonly kind: CanteenSourceErrorKind,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'CanteenSourceError';
  }
}

export interface FoodPlanRequest {
  locationId: number;
  from: string;
  to: string;
}

@Injectable()
export class MeineMensaClient {
  private readonly logger = new Logger(MeineMensaClient.name);

  constructor(@Inject(ENV) private readonly env: Env) {}

  async fetchFoodPlans(request: FoodPlanRequest): Promise<FoodPlanResponse> {
    const url = new URL(this.env.CANTEEN_SOURCE_URL);
    url.searchParams.set('location_id', String(request.locationId));
    url.searchParams.set('date_from', request.from);
    url.searchParams.set('date_to', request.to);

    const attempts = this.env.CANTEEN_RETRY_ATTEMPTS + 1;
    let lastError = new CanteenSourceError('network', 'request was never attempted');

    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        return await this.attempt(url);
      } catch (error) {
        lastError =
          error instanceof CanteenSourceError
            ? error
            : new CanteenSourceError('network', 'unexpected failure');

        // A malformed body will not fix itself on retry; only transport
        // problems and server errors are worth repeating.
        const retryable =
          lastError.kind === 'timeout' ||
          lastError.kind === 'network' ||
          (lastError.kind === 'http' && (lastError.status ?? 500) >= 500);

        if (!retryable || attempt === attempts) {
          break;
        }

        const backoffMs = 500 * 2 ** (attempt - 1);
        this.logger.warn(
          `Canteen source attempt ${attempt}/${attempts} failed (${lastError.kind}); retrying in ${backoffMs}ms`,
        );
        await new Promise((resolve) => setTimeout(resolve, backoffMs));
      }
    }

    throw lastError;
  }

  private async attempt(url: URL): Promise<FoodPlanResponse> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.env.CANTEEN_HTTP_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
        headers: { Accept: 'application/json' },
        // The source address is configuration, so following a redirect would
        // let the upstream — not this configuration — choose the host we talk
        // to, including one inside our own network. Same stance as the media
        // and ICS clients: a moved endpoint is a configuration change.
        redirect: 'error',
      });

      if (!response.ok) {
        throw new CanteenSourceError(
          'http',
          `source responded with status ${response.status}`,
          response.status,
        );
      }

      // Bounded WHILE reading, then parsed. `response.json()` would buffer the
      // whole body first, so any check after it is not a limit at all — see
      // common/http/bounded-body.ts.
      let body: string;
      try {
        body = await readBoundedText(response, this.env.CANTEEN_MAX_RESPONSE_BYTES);
      } catch (error) {
        if (error instanceof BodyTooLargeError) {
          throw new CanteenSourceError('malformed', 'source response exceeded the size limit');
        }
        throw error;
      }

      let payload: unknown;
      try {
        payload = JSON.parse(body);
      } catch {
        throw new CanteenSourceError('malformed', 'source returned a non-JSON body');
      }

      const parsed = foodPlanResponseSchema.safeParse(payload);
      if (!parsed.success) {
        throw new CanteenSourceError(
          'malformed',
          `source response failed validation (${parsed.error.issues.length} issue(s))`,
        );
      }

      return parsed.data;
    } catch (error) {
      if (error instanceof CanteenSourceError) {
        throw error;
      }
      if (error instanceof Error && error.name === 'AbortError') {
        throw new CanteenSourceError('timeout', 'source request timed out');
      }
      throw new CanteenSourceError('network', 'source is unreachable');
    } finally {
      clearTimeout(timer);
    }
  }
}
