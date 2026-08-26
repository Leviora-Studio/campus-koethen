import type { NextFunction, Request, Response } from 'express';
import {
  API_CONTENT_SECURITY_POLICY,
  DOCS_CONTENT_SECURITY_POLICY,
  HSTS_VALUE,
  createSecurityHeaders,
} from './security-headers';

/**
 * The headers every response carries.
 *
 * The middleware reads nothing but the request path and one boolean, so every
 * decision it makes can be stated here without a server or a socket.
 */
describe('createSecurityHeaders', () => {
  const run = (
    path: string,
    options: { production: boolean } = { production: false },
  ): { headers: Record<string, string>; nextCalled: boolean } => {
    const headers: Record<string, string> = {};
    const response = {
      setHeader: (name: string, value: string) => {
        headers[name] = value;
      },
    } as unknown as Response;
    let nextCalled = false;
    const next: NextFunction = () => {
      nextCalled = true;
    };
    createSecurityHeaders(options)({ path } as unknown as Request, response, next);
    return { headers, nextCalled };
  };

  it('sets the sniffing, framing and referrer guards on an API route', () => {
    const { headers, nextCalled } = run('/v1/posts');
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['Referrer-Policy']).toBe('no-referrer');
    expect(nextCalled).toBe(true);
  });

  // The media endpoint is the one that answers with bytes from an upload
  // directory, so it is the one that most needs `nosniff`.
  it('covers the media endpoint and the health probes as well', () => {
    for (const path of [
      '/v1/media/uploads/foto_5a141d3978.jpeg',
      '/health/live',
      '/health/ready',
    ]) {
      expect(run(path).headers['X-Content-Type-Options']).toBe('nosniff');
    }
  });

  it('gives the JSON API a policy that permits nothing at all', () => {
    expect(run('/v1/posts').headers['Content-Security-Policy']).toBe(API_CONTENT_SECURITY_POLICY);
    expect(API_CONTENT_SECURITY_POLICY).toContain("default-src 'none'");
  });

  // Swagger UI is a real page with an inline configuration block. A
  // `default-src 'none'` there would answer with a blank screen.
  it.each(['/docs', '/docs/', '/docs/swagger-ui-bundle.js', '/docs-json'])(
    'gives %s the docs policy instead',
    (path) => {
      const policy = run(path).headers['Content-Security-Policy'];
      expect(policy).toBe(DOCS_CONTENT_SECURITY_POLICY);
      expect(policy).not.toContain('default-src');
    },
  );

  // `/docsomething` is not the docs page; a prefix test would have said it was.
  it('does not mistake a route that merely begins with docs for the docs page', () => {
    expect(run('/docs-internal').headers['Content-Security-Policy']).toBe(
      API_CONTENT_SECURITY_POLICY,
    );
  });

  it('advertises HSTS only in production', () => {
    expect(run('/v1/posts', { production: false }).headers['Strict-Transport-Security']).toBe(
      undefined,
    );
    expect(run('/v1/posts', { production: true }).headers['Strict-Transport-Security']).toBe(
      HSTS_VALUE,
    );
  });
});
