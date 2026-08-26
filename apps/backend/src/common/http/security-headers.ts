import type { NextFunction, Request, RequestHandler, Response } from 'express';

/**
 * The response headers every answer of this API carries.
 *
 * The API is public and unauthenticated, so there is no session to steal — but
 * it is not only consumed by the Flutter client: `/docs` is a real HTML page, and
 * `/v1/media/uploads/:filename` returns bytes a browser will happily render. Both
 * live on the same origin, and without these headers that origin has no framing,
 * sniffing or referrer policy at all (AGENTS.md §3).
 *
 * Deliberately hand-written rather than pulled in as a dependency: this is five
 * constant headers, the set is small enough to read in one sitting, and the
 * project already writes its logger and its bounded body reader itself rather
 * than adding a package for each.
 */

/**
 * The JSON API renders nothing and loads nothing.
 *
 * `default-src 'none'` is therefore the honest policy: a browser that is ever
 * tricked into treating a response as a document may not fetch a script, a
 * style, an image or an endpoint from it. `frame-ancestors` repeats
 * `X-Frame-Options` for browsers that only honour the CSP form.
 */
export const API_CONTENT_SECURITY_POLICY =
  "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";

/**
 * The docs page is genuine HTML with inline bootstrap code, so it gets only the
 * directives that cannot break it.
 *
 * No `default-src` and no `script-src` here on purpose: Swagger UI is served
 * from this origin with an inline configuration block, and pinning its
 * resource loading is a change that would have to be verified against a running
 * page rather than asserted. What is pinned is what an attacker would need —
 * framing the page and rewriting its base or form targets.
 */
export const DOCS_CONTENT_SECURITY_POLICY =
  "frame-ancestors 'none'; base-uri 'none'; form-action 'self'";

/** One year, subdomains included. Only ever sent when TLS is actually in use. */
export const HSTS_VALUE = 'max-age=31536000; includeSubDomains';

/** Paths that serve the OpenAPI page and document rather than API JSON. */
function isDocsPath(path: string): boolean {
  return path === '/docs' || path.startsWith('/docs/') || path === '/docs-json';
}

export interface SecurityHeaderOptions {
  /**
   * Whether to advertise HSTS.
   *
   * Tied to the environment rather than to a guess about the current request:
   * the deployment terminates TLS in a reverse proxy, so the request that
   * reaches this process is plain HTTP and cannot be used to detect it. Sending
   * the header from a local development server would pin `localhost` to HTTPS
   * in the developer's browser for a year.
   */
  production: boolean;
}

/**
 * Sets the headers ahead of every route, including `/health` and `/docs`.
 *
 * Written as an ordinary Express middleware so it also covers responses the
 * exception filter produces — a 500 is exactly the response that should not
 * suddenly be sniffable or framable.
 */
export function createSecurityHeaders(options: SecurityHeaderOptions): RequestHandler {
  return function securityHeaders(request: Request, response: Response, next: NextFunction): void {
    // A browser must never guess at a content type here: the media endpoint
    // serves bytes that came from an upload directory.
    response.setHeader('X-Content-Type-Options', 'nosniff');
    // Nothing this API answers is meant to be embedded in another page.
    response.setHeader('X-Frame-Options', 'DENY');
    // A media path or a post slug is not worth handing to whatever a link
    // points at.
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader(
      'Content-Security-Policy',
      isDocsPath(request.path) ? DOCS_CONTENT_SECURITY_POLICY : API_CONTENT_SECURITY_POLICY,
    );
    if (options.production) {
      response.setHeader('Strict-Transport-Security', HSTS_VALUE);
    }
    next();
  };
}
