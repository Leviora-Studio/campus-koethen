import type { Core } from '@strapi/strapi';
import { corsOrigins } from '../src/security/cors-origins';

/**
 * `strapi::cors` is configured explicitly rather than listed by name.
 *
 * Listing it by name accepts the framework default, which is `origin: '*'` with
 * `credentials: true` — and its wildcard branch reflects the caller's own
 * `Origin` header instead of answering with a literal `*`, which is the form
 * browsers accept alongside credentials. AGENTS.md §3 requires the allowlist to
 * come from the environment and forbids a wildcard in production, exactly as
 * the Campus API already does. See src/security/cors-origins.ts.
 *
 * `credentials: false` because nothing here needs a cross-origin credentialed
 * request: the admin panel is served from the same origin it calls, and the
 * Campus API reads this CMS server-to-server with a bearer token, where CORS
 * plays no part at all.
 */
const config = ({ env }: Core.Config.Shared.ConfigParams): Core.Config.Middlewares => [
  'strapi::logger',
  'strapi::errors',
  'strapi::security',
  {
    name: 'strapi::cors',
    config: {
      origin: corsOrigins({
        allowlist: env('CORS_ALLOWED_ORIGINS', ''),
        publicUrl: env('PUBLIC_URL', ''),
        production: env('NODE_ENV', 'development') === 'production',
      }),
      credentials: false,
    },
  },
  // Deliberately omit `strapi::poweredBy`: disclosing the framework and its
  // version gives automated probes information the public CMS does not need
  // to advertise.
  'strapi::query',
  'strapi::body',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];

export default config;
