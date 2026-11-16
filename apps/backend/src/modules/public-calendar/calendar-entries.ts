import { z } from 'zod';
import { publicMediaUrl } from '../media/media.path';
import { computeEventKey } from './public-calendar.service';
import { PublicCalendarEventDto } from './public-calendar.types';

const zone = z
  .string()
  .max(80)
  .refine((value) => {
    try {
      new Intl.DateTimeFormat('en', { timeZone: value });
      return true;
    } catch {
      return false;
    }
  });
const link = z.object({
  label: z.string().min(1).max(160),
  url: z.string().url().max(2048).startsWith('https://'),
});
const media = z.object({
  url: z.string(),
  name: z.string().optional(),
  mime: z.string().optional(),
});
export const editorialEntrySchema = z
  .object({
    slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    title: z.string().min(1).max(200),
    description: z.string().max(20000).nullish(),
    location: z.string().max(500).nullish(),
    start: z.string().datetime({ offset: true }),
    end: z.string().datetime({ offset: true }),
    timeZone: zone,
    allDay: z.boolean().default(false),
    image: media.nullish(),
    links: z.array(link).max(50).nullish(),
    attachments: z.array(media).max(50).nullish(),
  })
  .refine((v) => Date.parse(v.end) > Date.parse(v.start))
  .refine(
    (v) =>
      !v.allDay ||
      [v.start, v.end].every((date) => new Date(date).toISOString().endsWith('T00:00:00.000Z')),
  );

export function parseEditorialEntry(
  raw: unknown,
  calendarSlug: string,
  calendarId: string,
): PublicCalendarEventDto | null {
  const parsed = editorialEntrySchema.safeParse(raw);
  if (!parsed.success) return null;
  const v = parsed.data;
  return {
    id: computeEventKey(calendarSlug, `editorial:${v.slug}`),
    calendarSlug,
    calendarId,
    title: v.title,
    description: v.description ?? null,
    location: v.location ?? null,
    start: new Date(v.start).toISOString(),
    end: new Date(v.end).toISOString(),
    allDay: v.allDay,
    status: 'confirmed',
    source: 'editorial',
    timeZone: v.timeZone,
    imageUrl: publicMediaUrl(v.image?.url),
    links: v.links ?? [],
    attachments: (v.attachments ?? []).flatMap((file) => {
      const url = publicMediaUrl(file.url);
      return url
        ? [
            {
              url: url.replace('/media/uploads/', '/media/files/'),
              name: file.name ?? '',
              mimeType: file.mime ?? 'application/octet-stream',
            },
          ]
        : [];
    }),
  };
}

/** Calendar attribution + whitespace-normalised, case-sensitive title + exact UTC period. */
export function mergeCalendarEntries(entries: PublicCalendarEventDto[]): PublicCalendarEventDto[] {
  const ranks = { editorial: 0, post: 1, google: 2 };
  const sorted = [...entries].sort(
    (a, b) => ranks[a.source ?? 'google'] - ranks[b.source ?? 'google'] || a.id.localeCompare(b.id),
  );
  const kept = new Map<string, PublicCalendarEventDto>();
  for (const e of sorted) {
    const key = JSON.stringify([
      e.calendarSlug,
      e.title.trim().replace(/\s+/g, ' '),
      Date.parse(e.start),
      Date.parse(e.end),
      e.allDay,
    ]);
    if (!kept.has(key)) kept.set(key, e);
  }
  return [...kept.values()].sort(
    (a, b) => a.start.localeCompare(b.start) || a.id.localeCompare(b.id),
  );
}
