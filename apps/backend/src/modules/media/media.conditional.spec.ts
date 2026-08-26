import { parseIfNoneMatch } from './media.conditional';

/**
 * This header ends up on an outbound request to Strapi, so what is refused
 * matters as much as what is accepted. Refused means "sent unconditionally" —
 * never "request fails".
 */
describe('parseIfNoneMatch', () => {
  it('accepts a single strong entity-tag and names it', () => {
    expect(parseIfNoneMatch('"abc"')).toEqual({ header: '"abc"', sole: '"abc"' });
  });

  it('accepts a weak entity-tag, weakness intact', () => {
    expect(parseIfNoneMatch('W/"1a2b-18f0c9d4e10"')).toEqual({
      header: 'W/"1a2b-18f0c9d4e10"',
      sole: 'W/"1a2b-18f0c9d4e10"',
    });
  });

  it('accepts a list but names no single tag, because it cannot know which matched', () => {
    expect(parseIfNoneMatch('"a", W/"b" ,"c"')).toEqual({
      header: '"a", W/"b", "c"',
      sole: null,
    });
  });

  it('accepts the wildcard and names no tag', () => {
    expect(parseIfNoneMatch('*')).toEqual({ header: '*', sole: null });
  });

  it('ignores surrounding whitespace', () => {
    expect(parseIfNoneMatch('  "abc" ')).toEqual({ header: '"abc"', sole: '"abc"' });
  });

  it.each([
    ['an absent header', undefined],
    ['a non-string', 42],
    ['an empty value', ''],
    ['whitespace only', '   '],
    ['an unquoted token', 'abc'],
    ['a half-quoted value', '"abc'],
    ['a lowercase weakness prefix', 'w/"abc"'],
    ['an embedded quote', '"a"b"'],
    ['an empty element in the list', '"a", , "b"'],
    ['a trailing comma', '"a",'],
    ['a non-ASCII tag', '"ä"'],
    ['a DEL character', '"a\x7f"'],
  ])('refuses %s', (_label, value) => {
    expect(parseIfNoneMatch(value)).toBeNull();
  });

  it('refuses a value longer than the limit', () => {
    // 256 characters including both quotes is the last accepted length.
    expect(parseIfNoneMatch(`"${'a'.repeat(254)}"`)).not.toBeNull();
    expect(parseIfNoneMatch(`"${'a'.repeat(255)}"`)).toBeNull();
  });

  it('refuses anything that could smuggle a second header upstream', () => {
    expect(parseIfNoneMatch('"abc"\r\nX-Injected: 1')).toBeNull();
    expect(parseIfNoneMatch('"abc"\nX-Injected: 1')).toBeNull();
    expect(parseIfNoneMatch('"a\x00b"')).toBeNull();
  });
});
