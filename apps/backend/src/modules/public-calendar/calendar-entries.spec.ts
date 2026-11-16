import { mergeCalendarEntries, parseEditorialEntry } from './calendar-entries';

describe('editorial calendar entries', () => {
  const raw = {
    slug: 'demo-event',
    title: 'Demo event',
    start: '2026-11-16T10:00:00Z',
    end: '2026-11-16T11:00:00Z',
    timeZone: 'Europe/Berlin',
    allDay: false,
  };
  it('validates dates, IANA zones and safe links at the trust boundary', () => {
    expect(parseEditorialEntry(raw, 'demo', 'cal')?.timeZone).toBe('Europe/Berlin');
    expect(parseEditorialEntry({ ...raw, end: raw.start }, 'demo', 'cal')).toBeNull();
    expect(parseEditorialEntry({ ...raw, timeZone: 'invalid' }, 'demo', 'cal')).toBeNull();
    expect(
      parseEditorialEntry(
        { ...raw, links: [{ label: 'Demo', url: 'javascript:alert(1)' }] },
        'demo',
        'cal',
      ),
    ).toBeNull();
  });
  it('deduplicates by title AND full period, preferring editorial entries', () => {
    const editorial = parseEditorialEntry(raw, 'demo', 'cal')!;
    const google = { ...editorial, id: 'google', source: 'google' as const };
    const post = { ...editorial, id: 'post', source: 'post' as const };
    expect(mergeCalendarEntries([google, post, editorial])).toEqual([editorial]);
    expect(mergeCalendarEntries([google, { ...editorial, title: 'Other demo' }])).toHaveLength(2);
    expect(
      mergeCalendarEntries([google, { ...editorial, end: '2026-11-16T12:00:00.000Z' }]),
    ).toHaveLength(2);
    expect(mergeCalendarEntries([google, { ...editorial, calendarSlug: 'other' }])).toHaveLength(2);
  });
  it('deduplicates all-day civil dates with implicit one-day post endings', () => {
    const editorial = parseEditorialEntry(
      { ...raw, start: '2026-11-16T00:00:00Z', end: '2026-11-17T00:00:00Z', allDay: true },
      'demo',
      'cal',
    )!;
    expect(
      mergeCalendarEntries([
        {
          ...editorial,
          id: 'post',
          source: 'post',
          start: '2026-11-16T12:00:00Z',
          end: '2026-11-16T12:00:00Z',
        },
        editorial,
      ]),
    ).toEqual([editorial]);
  });
  it('maps media through the Campus API and never exposes Strapi internals', () => {
    const entry = parseEditorialEntry(
      {
        ...raw,
        documentId: 'internal',
        image: { url: '/uploads/demo.png' },
        attachments: [{ url: '/uploads/demo.pdf', name: 'Demo PDF', mime: 'application/pdf' }],
      },
      'demo',
      'cal',
    )!;
    expect(entry.imageUrl).toBe('/v1/media/uploads/demo.png');
    expect(entry.attachments![0]!.url).toBe('/v1/media/files/demo.pdf');
    expect(entry).not.toHaveProperty('documentId');
  });
});
