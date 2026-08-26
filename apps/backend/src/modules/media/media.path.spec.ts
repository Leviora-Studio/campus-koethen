import { isAllowedMediaType, normaliseMediaPath, publicMediaUrl } from './media.path';

/**
 * The media endpoint fetches a URL derived from input. These are the rules
 * that keep that from becoming a server-side request forgery.
 */
describe('normaliseMediaPath', () => {
  it('accepts what Strapi actually produces', () => {
    expect(normaliseMediaPath('/uploads/foto_5a141d3978.jpeg')).toBe(
      '/uploads/foto_5a141d3978.jpeg',
    );
    expect(normaliseMediaPath('/uploads/A-B_c.123.png')).toBe('/uploads/A-B_c.123.png');
  });

  it('takes only the path of an absolute URL from a remote provider', () => {
    // The host comes from configuration, never from the payload.
    expect(normaliseMediaPath('https://cdn.example/uploads/foto.png')).toBe('/uploads/foto.png');
  });

  it('refuses anything outside the upload directory', () => {
    expect(normaliseMediaPath('/etc/passwd')).toBeNull();
    expect(normaliseMediaPath('/admin')).toBeNull();
    expect(normaliseMediaPath('/api/contact-persons')).toBeNull();
    expect(normaliseMediaPath('/uploadsfoo.png')).toBeNull();
  });

  it('refuses traversal in every form', () => {
    expect(normaliseMediaPath('/uploads/../../etc/passwd')).toBeNull();
    expect(normaliseMediaPath('/uploads/..%2F..%2Fetc%2Fpasswd')).toBeNull();
    expect(normaliseMediaPath('/uploads/%2e%2e/secret.png')).toBeNull();
    expect(normaliseMediaPath('/uploads/..')).toBeNull();
    expect(normaliseMediaPath('/uploads/sub/dir/foto.png')).toBeNull();
  });

  it('refuses a query or a fragment', () => {
    expect(normaliseMediaPath('/uploads/foto.png?token=x')).toBeNull();
    expect(normaliseMediaPath('/uploads/foto.png#x')).toBeNull();
  });

  it('refuses schemes that are not http(s)', () => {
    expect(normaliseMediaPath('file:///etc/passwd')).toBeNull();
    expect(normaliseMediaPath('gopher://internal/uploads/x.png')).toBeNull();
    expect(normaliseMediaPath('data:image/png;base64,AAAA')).toBeNull();
  });

  it('refuses the shapes that are not a path at all', () => {
    expect(normaliseMediaPath(null)).toBeNull();
    expect(normaliseMediaPath(undefined)).toBeNull();
    expect(normaliseMediaPath(42)).toBeNull();
    expect(normaliseMediaPath('')).toBeNull();
    expect(normaliseMediaPath('   ')).toBeNull();
    expect(normaliseMediaPath(`/uploads/${'x'.repeat(600)}.png`)).toBeNull();
  });

  it('refuses whitespace and control characters in a filename', () => {
    expect(normaliseMediaPath('/uploads/foto .png')).toBeNull();
    expect(normaliseMediaPath('/uploads/foto\n.png')).toBeNull();
  });
});

describe('publicMediaUrl', () => {
  it('publishes a relative Campus API path, never Strapi', () => {
    // Strapi's address is configuration, not payload (AGENTS.md §2.4).
    expect(publicMediaUrl('/uploads/foto.png')).toBe('/v1/media/uploads/foto.png');
    expect(publicMediaUrl('https://cms.internal/uploads/foto.png')).toBe(
      '/v1/media/uploads/foto.png',
    );
    expect(publicMediaUrl('https://cms.internal/uploads/foto.png')).not.toContain('cms.internal');
  });

  it('is null for anything that must not be served', () => {
    expect(publicMediaUrl('/etc/passwd')).toBeNull();
    expect(publicMediaUrl(null)).toBeNull();
  });
});

describe('isAllowedMediaType', () => {
  it('passes images through', () => {
    expect(isAllowedMediaType('image/png')).toBe(true);
    expect(isAllowedMediaType('image/jpeg; charset=binary')).toBe(true);
    expect(isAllowedMediaType('IMAGE/WEBP')).toBe(true);
  });

  it('refuses everything else', () => {
    // Otherwise this becomes a general file proxy for the whole media library.
    expect(isAllowedMediaType('application/pdf')).toBe(false);
    expect(isAllowedMediaType('text/html')).toBe(false);
    expect(isAllowedMediaType('application/octet-stream')).toBe(false);
    expect(isAllowedMediaType(null)).toBe(false);
    expect(isAllowedMediaType('')).toBe(false);
  });

  it('refuses SVG, which is a script-bearing document rather than a picture', () => {
    // The endpoint answers with `Content-Disposition: inline`, so a browser
    // would execute a `<script>` inside an editor-uploaded SVG on this API's
    // own origin. No client of this project can render remote SVG anyway:
    // RemoteImage uses Image.network, and flutter_svg is only ever used on
    // bundled map assets.
    expect(isAllowedMediaType('image/svg+xml')).toBe(false);
    expect(isAllowedMediaType('IMAGE/SVG+XML; charset=utf-8')).toBe(false);
  });
});
