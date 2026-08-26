/**
 * Locale contract of the Campus API — see docs/api.md §2.
 *
 * Resolution order:
 *   1. explicit `locale` query parameter  (unsupported value => 400)
 *   2. `Accept-Language` header           (unsupported value => silent de)
 *   3. default `de`
 *
 * The asymmetry is deliberate: an explicit request is never silently altered,
 * while a browser-sent header is a hint and may fall back quietly.
 */

export const SUPPORTED_LOCALES = ['de', 'en'] as const;

export type Locale = (typeof SUPPORTED_LOCALES)[number];

export const DEFAULT_LOCALE: Locale = 'de';

export class UnsupportedLocaleError extends Error {
  constructor(public readonly requested: string) {
    super(`Unsupported locale: ${requested}`);
    this.name = 'UnsupportedLocaleError';
  }
}

export function isSupportedLocale(value: string): value is Locale {
  return (SUPPORTED_LOCALES as readonly string[]).includes(value);
}

/**
 * Picks the best supported locale from an `Accept-Language` header value.
 * Returns `null` when the header expresses no supported preference, so the
 * caller applies the documented default rather than guessing here.
 */
export function parseAcceptLanguage(header: string | undefined | null): Locale | null {
  if (!header) {
    return null;
  }

  const candidates = header
    .split(',')
    .map((part) => {
      const [tagPart, ...params] = part.trim().split(';');
      const tag = (tagPart ?? '').trim().toLowerCase();
      if (!tag || tag === '*') {
        return null;
      }

      // A malformed or missing q defaults to 1.0 rather than discarding the tag.
      let quality = 1;
      for (const param of params) {
        const [key, rawValue] = param.split('=').map((s) => s.trim());
        if (key === 'q') {
          const parsed = Number.parseFloat(rawValue ?? '');
          if (Number.isFinite(parsed)) {
            quality = parsed;
          }
        }
      }

      // `de-AT` must match the base tag `de`.
      const baseTag = tag.split('-')[0] ?? tag;
      return isSupportedLocale(baseTag) ? { locale: baseTag, quality } : null;
    })
    .filter((candidate): candidate is { locale: Locale; quality: number } => candidate !== null)
    .filter((candidate) => candidate.quality > 0);

  if (candidates.length === 0) {
    return null;
  }

  // Highest quality wins; document order breaks ties.
  return candidates.reduce((best, current) => (current.quality > best.quality ? current : best))
    .locale;
}

export interface LocaleResolution {
  /** What the client asked for, after normalisation. */
  requestedLocale: Locale;
  /** What is actually being served. */
  resolvedLocale: Locale;
}

export function resolveLocale(input: {
  queryLocale?: string | undefined;
  acceptLanguage?: string | undefined;
}): LocaleResolution {
  const queryLocale = input.queryLocale?.trim();

  if (queryLocale) {
    const normalised = queryLocale.toLowerCase();
    if (!isSupportedLocale(normalised)) {
      throw new UnsupportedLocaleError(queryLocale);
    }
    return { requestedLocale: normalised, resolvedLocale: normalised };
  }

  const fromHeader = parseAcceptLanguage(input.acceptLanguage);
  const locale = fromHeader ?? DEFAULT_LOCALE;
  return { requestedLocale: locale, resolvedLocale: locale };
}
