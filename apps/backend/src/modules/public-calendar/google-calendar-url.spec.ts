import {
  InvalidShareUrlError,
  buildCombinedEmbedUrl,
  buildIcsFeedUrl,
  buildSingleOpenUrl,
  extractCalendarId,
  isValidTimeZone,
  tryExtractCalendarId,
} from './google-calendar-url';

/**
 * All fixtures are synthetic. The calendar id below is a made-up value that
 * mimics the shape of a Google group-calendar id — it is NOT a real calendar.
 */
const SYNTHETIC_ID = 'beispielkalender-a@group.calendar.google.com';

/** Builds a `cid` the way Google does: base64url of the calendar id. */
function cidFor(id: string): string {
  return Buffer.from(id, 'utf8').toString('base64url');
}

function shareUrl(cid: string, path = '/calendar/render'): string {
  return `https://calendar.google.com${path}?cid=${cid}`;
}

describe('extractCalendarId — accepted public share links', () => {
  it('accepts the render form', () => {
    expect(extractCalendarId(shareUrl(cidFor(SYNTHETIC_ID)))).toBe(SYNTHETIC_ID);
  });

  it('accepts the /calendar/u/0 form', () => {
    expect(extractCalendarId(shareUrl(cidFor(SYNTHETIC_ID), '/calendar/u/0'))).toBe(SYNTHETIC_ID);
  });

  it('accepts the /calendar/u/0/r form', () => {
    expect(extractCalendarId(shareUrl(cidFor(SYNTHETIC_ID), '/calendar/u/0/r'))).toBe(SYNTHETIC_ID);
  });

  it('accepts standard base64 (with +/ and padding) in the cid', () => {
    // A synthetic id whose base64 contains + and / and padding.
    const id = 'øœ-kalender@group.calendar.google.com';
    const standard = Buffer.from(id, 'utf8').toString('base64'); // may contain +,/,=
    expect(extractCalendarId(shareUrl(standard))).toBe(id);
  });
});

describe('extractCalendarId — rejected transport / host', () => {
  const cases: Array<[string, string]> = [
    ['http (not https)', 'http://calendar.google.com/calendar/render?cid=' + cidFor(SYNTHETIC_ID)],
    ['webcal scheme', 'webcal://calendar.google.com/calendar/render?cid=' + cidFor(SYNTHETIC_ID)],
    [
      'host suffix attack',
      'https://calendar.google.com.attacker.example/calendar/render?cid=' + cidFor(SYNTHETIC_ID),
    ],
    [
      'parent-domain attack',
      'https://google.com.attacker.example/calendar/render?cid=' + cidFor(SYNTHETIC_ID),
    ],
    [
      'unknown google subdomain',
      'https://evil.calendar.google.com/calendar/render?cid=' + cidFor(SYNTHETIC_ID),
    ],
    [
      'userinfo attack',
      'https://user@calendar.google.com/calendar/render?cid=' + cidFor(SYNTHETIC_ID),
    ],
    [
      'explicit port',
      'https://calendar.google.com:8443/calendar/render?cid=' + cidFor(SYNTHETIC_ID),
    ],
    ['ip address', 'https://127.0.0.1/calendar/render?cid=' + cidFor(SYNTHETIC_ID)],
    ['garbage', 'not a url at all'],
  ];
  it.each(cases)('rejects %s', (_label, url) => {
    expect(() => extractCalendarId(url)).toThrow(InvalidShareUrlError);
  });
});

describe('extractCalendarId — rejected path / private feeds', () => {
  const cases: Array<[string, string]> = [
    [
      'private basic.ics feed',
      'https://calendar.google.com/calendar/ical/x%40group.calendar.google.com/private-abcdef/basic.ics',
    ],
    [
      'public basic.ics feed pasted directly',
      'https://calendar.google.com/calendar/ical/x%40group.calendar.google.com/public/basic.ics',
    ],
    ['embed url pasted directly', 'https://calendar.google.com/calendar/embed?src=' + SYNTHETIC_ID],
    ['unknown path', 'https://calendar.google.com/foo/bar?cid=' + cidFor(SYNTHETIC_ID)],
    [
      'path traversal',
      'https://calendar.google.com/calendar/../secret?cid=' + cidFor(SYNTHETIC_ID),
    ],
  ];
  it.each(cases)('rejects %s', (_label, url) => {
    expect(() => extractCalendarId(url)).toThrow(InvalidShareUrlError);
  });
});

describe('extractCalendarId — rejected cid', () => {
  it('rejects a missing cid', () => {
    expect(() => extractCalendarId('https://calendar.google.com/calendar/render')).toThrow(
      InvalidShareUrlError,
    );
  });

  it('rejects an empty cid', () => {
    expect(() => extractCalendarId('https://calendar.google.com/calendar/render?cid=')).toThrow(
      InvalidShareUrlError,
    );
  });

  it('rejects multiple cid parameters', () => {
    const cid = cidFor(SYNTHETIC_ID);
    expect(() =>
      extractCalendarId(`https://calendar.google.com/calendar/render?cid=${cid}&cid=${cid}`),
    ).toThrow(InvalidShareUrlError);
  });

  it('rejects a non-base64 cid', () => {
    expect(() => extractCalendarId(shareUrl('!!!not-base64!!!'))).toThrow(InvalidShareUrlError);
  });

  it('rejects a cid that decodes to invalid UTF-8', () => {
    const cid = Buffer.from([0xff, 0xfe, 0xfd, 0xfc]).toString('base64url');
    expect(() => extractCalendarId(shareUrl(cid))).toThrow(InvalidShareUrlError);
  });

  it('rejects an over-long cid', () => {
    const cid = 'A'.repeat(4000);
    const result = tryExtractCalendarId(shareUrl(cid));
    expect(result.ok).toBe(false);
  });

  it('rejects a decoded id containing a newline', () => {
    expect(() => extractCalendarId(shareUrl(cidFor('abc\ndef@group.calendar.google.com')))).toThrow(
      InvalidShareUrlError,
    );
  });

  it('rejects a decoded id containing a NUL byte', () => {
    expect(() => extractCalendarId(shareUrl(cidFor('abc\0def')))).toThrow(InvalidShareUrlError);
  });

  it('rejects a decoded id with leading/trailing whitespace', () => {
    expect(() =>
      extractCalendarId(shareUrl(cidFor('  spaced@group.calendar.google.com  '))),
    ).toThrow(InvalidShareUrlError);
  });

  it('rejects a decoded id that is too long', () => {
    const longId = 'a'.repeat(500) + '@group.calendar.google.com';
    expect(() => extractCalendarId(shareUrl(cidFor(longId)))).toThrow(InvalidShareUrlError);
  });
});

describe('tryExtractCalendarId', () => {
  it('returns ok on a valid link', () => {
    expect(tryExtractCalendarId(shareUrl(cidFor(SYNTHETIC_ID)))).toEqual({
      ok: true,
      calendarId: SYNTHETIC_ID,
    });
  });
  it('returns a classified error otherwise', () => {
    const r = tryExtractCalendarId('http://calendar.google.com/calendar/render?cid=x');
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.kind).toBe('notHttps');
  });
});

describe('buildIcsFeedUrl — the ONLY constructed feed', () => {
  it('builds the fixed public feed with the id as a single encoded path segment', () => {
    const url = buildIcsFeedUrl(SYNTHETIC_ID);
    expect(url).toBe(
      'https://calendar.google.com/calendar/ical/' +
        encodeURIComponent(SYNTHETIC_ID) +
        '/public/basic.ics',
    );
    // The '@' must be percent-encoded so the id can never break out of its segment.
    expect(url).toContain('%40');
    expect(url).not.toContain('@');
    const parsed = new URL(url);
    expect(parsed.protocol).toBe('https:');
    expect(parsed.hostname).toBe('calendar.google.com');
  });

  it('cannot be tricked into path traversal even with slashes in the id', () => {
    const url = buildIcsFeedUrl('a/../../etc/passwd');
    expect(url).not.toContain('/../');
    expect(url).toContain('%2F');
    // Still on the fixed host and the ical path.
    expect(url.startsWith('https://calendar.google.com/calendar/ical/')).toBe(true);
    expect(url.endsWith('/public/basic.ics')).toBe(true);
  });
});

describe('buildSingleOpenUrl', () => {
  it('builds a render?cid= url with a base64url cid that round-trips', () => {
    const url = buildSingleOpenUrl(SYNTHETIC_ID);
    const parsed = new URL(url);
    expect(parsed.hostname).toBe('calendar.google.com');
    expect(parsed.pathname).toBe('/calendar/render');
    const cid = parsed.searchParams.get('cid');
    expect(cid).not.toBeNull();
    expect(extractCalendarId(url)).toBe(SYNTHETIC_ID);
  });
});

describe('buildCombinedEmbedUrl', () => {
  it('builds an embed url with one src per calendar and a fixed ctz', () => {
    const url = buildCombinedEmbedUrl([SYNTHETIC_ID, 'zweiter@group.calendar.google.com']);
    const parsed = new URL(url);
    expect(parsed.hostname).toBe('calendar.google.com');
    expect(parsed.pathname).toBe('/calendar/embed');
    expect(parsed.searchParams.getAll('src')).toEqual([
      SYNTHETIC_ID,
      'zweiter@group.calendar.google.com',
    ]);
    expect(parsed.searchParams.get('ctz')).toBe('Europe/Berlin');
  });

  it('rejects an empty calendar list', () => {
    expect(() => buildCombinedEmbedUrl([])).toThrow();
  });

  it('rejects an unsafe timezone and keeps the default otherwise', () => {
    expect(isValidTimeZone('Europe/Berlin')).toBe(true);
    expect(isValidTimeZone('Etc/UTC')).toBe(true);
    expect(isValidTimeZone('foo bar; drop')).toBe(false);
    expect(() => buildCombinedEmbedUrl([SYNTHETIC_ID], 'foo bar; drop')).toThrow();
  });
});
