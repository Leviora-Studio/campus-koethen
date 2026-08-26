import type { Core } from '@strapi/strapi';

/**
 * Ensures the CMS speaks exactly the two locales this project supports.
 *
 * German is the DEFAULT and the fallback: it is the canonical set the Campus
 * API reads, and any content without an English translation is served as
 * German with `translationFallback: true` rather than being machine-translated
 * or silently hidden.
 *
 * Idempotent — safe to run on every boot.
 */

export const DEFAULT_LOCALE = 'de';
export const SUPPORTED_LOCALES = [
  { code: 'de', name: 'German (de)', isDefault: true },
  { code: 'en', name: 'English (en)', isDefault: false },
] as const;

export async function ensureLocales(strapi: Core.Strapi): Promise<void> {
  const localesService = strapi.plugin('i18n')?.service('locales') as
    | {
        find(): Promise<Array<{ id: number; code: string; isDefault?: boolean }>>;
        create(data: { code: string; name: string; isDefault?: boolean }): Promise<unknown>;
        setDefaultLocale(input: { code: string }): Promise<unknown>;
      }
    | undefined;

  if (!localesService) {
    strapi.log.warn('i18n plugin is unavailable; skipping locale bootstrap');
    return;
  }

  const existing = await localesService.find();
  const byCode = new Map(existing.map((locale) => [locale.code, locale]));

  for (const locale of SUPPORTED_LOCALES) {
    if (!byCode.has(locale.code)) {
      await localesService.create({ code: locale.code, name: locale.name });
      strapi.log.info(`[locales] created locale ${locale.code}`);
    }
  }

  const current = await localesService.find();
  const german = current.find((locale) => locale.code === DEFAULT_LOCALE);
  if (german && !german.isDefault) {
    await localesService.setDefaultLocale({ code: DEFAULT_LOCALE });
    strapi.log.info(`[locales] set ${DEFAULT_LOCALE} as the default locale`);
  }
}
