import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { foodPlanResponseSchema, normalizeDefinitions, normalizeEntry } from './meine-mensa.schema';

const fixture = (name: string): unknown =>
  JSON.parse(readFileSync(join(__dirname, '../../../test/fixtures/meine-mensa', name), 'utf8'));

describe('meine-mensa schema', () => {
  it('accepts the real-world success shape', () => {
    const parsed = foodPlanResponseSchema.safeParse(fixture('success.json'));
    expect(parsed.success).toBe(true);
    expect(parsed.success && parsed.data.data).toHaveLength(3);
  });

  it('accepts an empty data array as a VALID response', () => {
    // Emptiness is a legitimate answer (e.g. semester break), not a schema error.
    // The decision to keep existing data is made by the sync service, not here.
    const parsed = foodPlanResponseSchema.safeParse(fixture('empty.json'));
    expect(parsed.success).toBe(true);
    expect(parsed.success && parsed.data.data).toEqual([]);
  });

  it('rejects a structurally malformed response', () => {
    expect(foodPlanResponseSchema.safeParse(fixture('malformed.json')).success).toBe(false);
  });

  it('rejects an entry without a stable id', () => {
    const result = foodPlanResponseSchema.safeParse({
      data: [{ date: '2026-07-20', location_id: 7, food: { name: 'X' } }],
    });
    expect(result.success).toBe(false);
  });

  it('rejects a malformed date', () => {
    const result = foodPlanResponseSchema.safeParse({
      data: [{ id: 1, date: '20.07.2026', location_id: 7, food: { name: 'X' } }],
    });
    expect(result.success).toBe(false);
  });

  it('rejects a non-numeric price rather than coercing it', () => {
    const result = foodPlanResponseSchema.safeParse({
      data: [{ id: 1, date: '2026-07-20', location_id: 7, food: { name: 'X', price_1: '1,95' } }],
    });
    expect(result.success).toBe(false);
  });

  describe('price handling', () => {
    it('converts prices to fixed-scale decimal strings', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      const meal = normalizeEntry(parsed.data[0]!);
      expect(meal.prices).toEqual([
        { group: 'student', amount: '1.95' },
        { group: 'employee', amount: '4.95' },
        { group: 'guest', amount: '7.00' },
      ]);
    });

    it('omits a missing price group instead of defaulting it to zero', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('partial-prices.json'));
      const meal = normalizeEntry(parsed.data[0]!);
      expect(meal.prices.map((p) => p.group)).toEqual(['student', 'guest']);
      expect(meal.prices.find((p) => p.group === 'employee')).toBeUndefined();
    });
  });

  describe('normalizeEntry', () => {
    it('never carries the source image url into the internal shape', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      const meal = normalizeEntry(parsed.data[0]!);
      expect(JSON.stringify(meal)).not.toContain('image');
      expect(JSON.stringify(meal)).not.toContain('mediathek');
    });

    it('drops empty extras and keeps the filled ones', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      expect(normalizeEntry(parsed.data[0]!).extras).toEqual([]);
      expect(normalizeEntry(parsed.data[1]!).extras).toEqual(['dazu Salat', 'Dessert']);
    });

    it('normalises an empty name_2 to null', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('partial-prices.json'));
      expect(normalizeEntry(parsed.data[0]!).subtitle).toBeNull();
    });

    it('keeps ingredient codes as strings, including alphanumeric ones', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      expect(normalizeEntry(parsed.data[0]!).ingredientCodes).toEqual([
        '2',
        '52',
        '53',
        'A1',
        'G2',
      ]);
    });

    it('preserves the source text verbatim without translating it', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      const meal = normalizeEntry(parsed.data[0]!);
      expect(meal.name).toBe('Gemüsepfanne');
      expect(meal.subtitle).toBe('mit Kichererbsen und Kräuterdip');
    });
  });

  describe('normalizeDefinitions', () => {
    it('flattens both dictionaries and records which namespace each code came from', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      const definitions = normalizeDefinitions(parsed.meta);

      expect(definitions.find((d) => d.code === '52')).toEqual({
        code: '52',
        labelDe: 'vegan',
        kind: 'ingredient',
      });
      // '53' appears inside food.ingredients but is defined as a MARKER.
      expect(definitions.find((d) => d.code === '53')).toEqual({
        code: '53',
        labelDe: 'Sprint-Menü',
        kind: 'marker',
      });
    });

    it('never invents an English label', () => {
      const parsed = foodPlanResponseSchema.parse(fixture('success.json'));
      for (const definition of normalizeDefinitions(parsed.meta)) {
        expect(definition).not.toHaveProperty('labelEn');
      }
    });

    it('tolerates missing meta', () => {
      expect(normalizeDefinitions(null)).toEqual([]);
      expect(normalizeDefinitions(undefined)).toEqual([]);
    });
  });
});
