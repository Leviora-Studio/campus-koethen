import { z } from 'zod';
import { tryExtractCalendarId } from './google-calendar-url';
import { CalendarDefinition } from './public-calendar.types';

/**
 * Validation of the editorial calendar definitions coming from Strapi.
 *
 * This runs at the BACKEND trust boundary: even though Strapi's own validation
 * should already reject a bad share URL, the worker re-validates every field
 * here and re-derives the calendar id from the share link. A single invalid
 * entry is dropped (and counted), never taking the rest of the catalogue down.
 *
 * The app offers channel calendars; independent calendars remain available
 * to website readers. A linked calendar inherits its channel colour.
 */

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const COLOR_PATTERN = /^#[0-9A-Fa-f]{6}$/;

/** Strapi 5 returns flat attributes. Unknown extra keys are ignored. */
const strapiEntrySchema = z
  .object({
    slug: z.string(),
    name: z.string().min(1),
    googleShareUrl: z.string().nullish(),
    sortOrder: z.coerce.number().int().default(0),
    isActive: z.boolean().default(true),
    defaultSubscribed: z.boolean().default(false),
    includeEventDescription: z.boolean().default(false),
    includeEventLocation: z.boolean().default(false),
    channel: z
      .object({
        slug: z.string(),
        colorHex: z.string(),
      })
      .nullish(),
  })
  .passthrough();

export type StrapiEntry = z.infer<typeof strapiEntrySchema>;

export interface CatalogValidationResult {
  definitions: CalendarDefinition[];
  received: number;
  rejected: number;
  editorialOnlySlugs: string[];
}

/**
 * Validates the canonical (German) catalogue, overlaying English translations
 * keyed by the non-localised slug.
 */
export function validateCatalog(
  deEntries: unknown[],
  enEntries: unknown[],
): CatalogValidationResult {
  const enBySlug = new Map<string, StrapiEntry>();
  for (const raw of enEntries) {
    const parsed = strapiEntrySchema.safeParse(raw);
    if (parsed.success && SLUG_PATTERN.test(parsed.data.slug)) {
      enBySlug.set(parsed.data.slug, parsed.data);
    }
  }

  const definitions: CalendarDefinition[] = [];
  let rejected = 0;
  const editorialOnlySlugs: string[] = [];

  for (const raw of deEntries) {
    const parsed = strapiEntrySchema.safeParse(raw);
    if (!parsed.success) {
      rejected += 1;
      continue;
    }
    const entry = parsed.data;
    // Editorial-only calendars do not participate in the Google read model.
    if (!entry.googleShareUrl) {
      if (SLUG_PATTERN.test(entry.slug)) editorialOnlySlugs.push(entry.slug);
      else rejected += 1;
      continue;
    }

    const channel = entry.channel;
    if (
      !SLUG_PATTERN.test(entry.slug) ||
      (channel != null &&
        (!SLUG_PATTERN.test(channel.slug) || !COLOR_PATTERN.test(channel.colorHex)))
    ) {
      rejected += 1;
      continue;
    }
    const extracted = tryExtractCalendarId(entry.googleShareUrl);
    if (!extracted.ok) {
      rejected += 1;
      continue;
    }

    const en = enBySlug.get(entry.slug);

    definitions.push({
      slug: entry.slug,
      googleCalendarId: extracted.calendarId,
      channelSlug: channel?.slug ?? null,
      nameDe: entry.name,
      nameEn: en?.name ?? null,
      colorHex: channel?.colorHex.toUpperCase() ?? '#5B3FD0',
      sortOrder: entry.sortOrder,
      defaultSubscribed: entry.defaultSubscribed,
      includeEventDescription: entry.includeEventDescription,
      includeEventLocation: entry.includeEventLocation,
    });
  }

  return { definitions, received: deEntries.length, rejected, editorialOnlySlugs };
}
