import type { Request, Response } from 'express';
import { COMPRESSION_THRESHOLD_BYTES, shouldCompress } from './response-compression';

/**
 * Which responses this API is willing to compress.
 *
 * The interesting cases are the refusals, and they are cheap to state here:
 * the filter reads nothing but the response content type, so it can be decided
 * exhaustively without a server, a socket or a real payload.
 */
describe('shouldCompress', () => {
  const withContentType = (contentType: string | undefined): [Request, Response] => {
    const response = {
      getHeader: (name: string) =>
        name.toLowerCase() === 'content-type' ? contentType : undefined,
    } as unknown as Response;
    return [{ headers: {} } as unknown as Request, response];
  };

  it.each([
    'application/json',
    'application/json; charset=utf-8',
    'text/html; charset=utf-8',
    'text/plain',
  ])('compresses %s', (contentType) => {
    expect(shouldCompress(...withContentType(contentType))).toBe(true);
  });

  // The media endpoint's entire allowlist. Every one of these is already a
  // compressed container; running it through gzip costs CPU on both ends and
  // gives back nothing.
  it.each(['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/avif'])(
    'refuses %s — already compressed',
    (contentType) => {
      expect(shouldCompress(...withContentType(contentType))).toBe(false);
    },
  );

  it('matches the image family case-insensitively and ignores parameters', () => {
    expect(shouldCompress(...withContentType('IMAGE/JPEG'))).toBe(false);
    expect(shouldCompress(...withContentType('  image/webp; foo=bar'))).toBe(false);
  });

  it('refuses every image type, not only the ones mime-db calls incompressible', () => {
    // `image/svg+xml` IS compressible text and the default filter would take
    // it. The guard is on the family on purpose: what this API serves as an
    // image is decided by the media allowlist, not by a mime table.
    expect(shouldCompress(...withContentType('image/svg+xml'))).toBe(false);
  });

  it('refuses a response with no content type at all', () => {
    expect(shouldCompress(...withContentType(undefined))).toBe(false);
  });

  it('still refuses the already-compressed formats the default filter knows', () => {
    // Nothing in this API answers with either, but it shows what the fallback
    // is: the default filter, unchanged, not a blanket yes.
    expect(shouldCompress(...withContentType('application/pdf'))).toBe(false);
    expect(shouldCompress(...withContentType('application/zip'))).toBe(false);
  });

  it('keeps the threshold at one kilobyte', () => {
    // Named so the integration test and the documentation cannot drift from it.
    expect(COMPRESSION_THRESHOLD_BYTES).toBe(1024);
  });
});
