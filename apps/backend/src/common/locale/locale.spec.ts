import {
  DEFAULT_LOCALE,
  SUPPORTED_LOCALES,
  UnsupportedLocaleError,
  parseAcceptLanguage,
  resolveLocale,
} from './locale';

describe('locale contract', () => {
  it('supports exactly de and en, defaulting to de', () => {
    expect(SUPPORTED_LOCALES).toEqual(['de', 'en']);
    expect(DEFAULT_LOCALE).toBe('de');
  });

  describe('resolveLocale', () => {
    it('uses an explicit query parameter above everything else', () => {
      const result = resolveLocale({ queryLocale: 'en', acceptLanguage: 'de-DE,de;q=0.9' });
      expect(result).toEqual({ requestedLocale: 'en', resolvedLocale: 'en' });
    });

    it('rejects an explicit unsupported locale instead of silently substituting', () => {
      expect(() => resolveLocale({ queryLocale: 'fr' })).toThrow(UnsupportedLocaleError);
    });

    it('rejects an explicit unsupported locale even when Accept-Language is valid', () => {
      expect(() => resolveLocale({ queryLocale: 'fr', acceptLanguage: 'de' })).toThrow(
        UnsupportedLocaleError,
      );
    });

    it('falls back to Accept-Language when no query parameter is given', () => {
      expect(resolveLocale({ acceptLanguage: 'en-GB,en;q=0.9' })).toEqual({
        requestedLocale: 'en',
        resolvedLocale: 'en',
      });
    });

    it('falls back silently to de for an unsupported Accept-Language', () => {
      expect(resolveLocale({ acceptLanguage: 'fr-FR,fr;q=0.9' })).toEqual({
        requestedLocale: 'de',
        resolvedLocale: 'de',
      });
    });

    it('defaults to de when nothing is provided', () => {
      expect(resolveLocale({})).toEqual({ requestedLocale: 'de', resolvedLocale: 'de' });
    });

    it('accepts a query locale case-insensitively', () => {
      expect(resolveLocale({ queryLocale: 'EN' }).resolvedLocale).toBe('en');
    });

    it('treats an empty query locale as absent rather than invalid', () => {
      expect(resolveLocale({ queryLocale: '', acceptLanguage: 'en' }).resolvedLocale).toBe('en');
    });
  });

  describe('parseAcceptLanguage', () => {
    it('honours quality ordering rather than document order', () => {
      expect(parseAcceptLanguage('de;q=0.2, en;q=0.9')).toBe('en');
    });

    it('treats a missing q as 1.0', () => {
      expect(parseAcceptLanguage('en, de;q=0.9')).toBe('en');
    });

    it('matches the base tag of a regional variant', () => {
      expect(parseAcceptLanguage('de-AT')).toBe('de');
    });

    it('skips unsupported tags and picks the best supported one', () => {
      expect(parseAcceptLanguage('fr;q=1.0, en;q=0.4')).toBe('en');
    });

    it('returns null when nothing is supported', () => {
      expect(parseAcceptLanguage('fr,es')).toBeNull();
    });

    it('returns null for a wildcard so the caller applies the documented default', () => {
      expect(parseAcceptLanguage('*')).toBeNull();
    });

    it('is robust against malformed input', () => {
      expect(parseAcceptLanguage('')).toBeNull();
      expect(parseAcceptLanguage('   ')).toBeNull();
      expect(parseAcceptLanguage(';;;')).toBeNull();
      expect(parseAcceptLanguage('en;q=notanumber')).toBe('en');
    });
  });
});
