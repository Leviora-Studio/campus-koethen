// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/**
 * Which browser origins may call this CMS.
 *
 * Strapi's `strapi::cors` middleware defaults to `origin: '*'` with
 * `credentials: true`, and its wildcard branch does not answer with a literal
 * `*` — it REFLECTS whatever `Origin` the request carried. A reflected origin
 * next to `Access-Control-Allow-Credentials: true` is the combination browsers
 * accept, so the default turns every page on the internet into a permitted
 * cross-origin caller of the CMS.
 *
 * AGENTS.md §3 already settles what should happen instead: the allowlist comes
 * from the environment, and production never carries a wildcard. That rule was
 * implemented for the Campus API (`CORS_ALLOWED_ORIGINS`, validated at boot in
 * `apps/backend/src/config/env.schema.ts`) but not here, because listing
 * `'strapi::cors'` by name silently accepts the framework default.
 *
 * Kept as a pure function so every decision can be tested without booting
 * Strapi.
 */

export class CorsConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CorsConfigurationError';
  }
}

export interface CorsOriginInput {
  /** Comma-separated allowlist, exactly as the environment supplies it. */
  allowlist?: string | undefined;
  /** The address this CMS is served under; the admin panel's own origin. */
  publicUrl?: string | undefined;
  production: boolean;
}

/** The documented local default. Never used in production. */
export const DEVELOPMENT_ORIGIN = 'http://localhost:1337';

/** Reduces a URL to its origin, or `null` when it is not a usable one. */
function originOf(value: string): string | null {
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.origin;
  } catch {
    return null;
  }
}

/**
 * The explicit origin list for `strapi::cors`.
 *
 * Never returns a wildcard in production: a deployment that asks for one is a
 * configuration mistake and is refused at boot rather than served.
 *
 * Falls back to the CMS's own public address when the allowlist is absent. That
 * is the honest default rather than a permissive one — the admin panel is
 * served from exactly that origin, so same-origin requests (which is all the
 * admin panel makes) never involve CORS at all, and nothing else has a reason
 * to be trusted by default.
 */
export function corsOrigins(input: CorsOriginInput): string[] {
  const entries = (input.allowlist ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);

  if (entries.includes('*')) {
    if (input.production) {
      throw new CorsConfigurationError(
        'CORS_ALLOWED_ORIGINS must not contain "*" when NODE_ENV=production.',
      );
    }
    return ['*'];
  }

  if (entries.length > 0) {
    return entries;
  }

  const publicOrigin = originOf((input.publicUrl ?? '').trim());
  if (publicOrigin !== null) {
    return [publicOrigin];
  }

  // Nothing configured and nothing to infer. In production that is an EMPTY
  // allowlist, not a development default and certainly not a wildcard: no
  // cross-origin browser caller is permitted, which costs nothing because the
  // admin panel is same-origin and the Campus API reads this CMS
  // server-to-server, where CORS plays no part.
  //
  // Deliberately not an exception. `strapi build` and the Docker image build
  // both load this file with NODE_ENV=production and placeholder configuration,
  // so throwing here would fail the BUILD over a runtime setting — and a build
  // that cannot run is not a safer outcome than a CMS that accepts no
  // cross-origin caller.
  return input.production ? [] : [DEVELOPMENT_ORIGIN];
}
