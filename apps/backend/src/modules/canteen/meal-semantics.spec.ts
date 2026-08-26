import { classifyMeal, MEAL_ALLERGENS, MEAL_TRAITS } from './meal-semantics';

/**
 * The real dictionary `meine-mensa.de` returns in `meta.ingredients` and
 * `meta.markers`, captured verbatim. The mapping exists to survive exactly this
 * input, so the test uses it rather than a tidied-up version of it.
 */
const UPSTREAM_LABELS: Record<string, string> = {
  '1': 'Farbstoffe',
  '2': 'Konservierungsstoffe',
  '45': 'Schwein',
  '46': 'Rind',
  '47': 'Geflügel',
  '48': 'Fisch',
  '49': 'Wild',
  '50': 'fleischlos',
  '51': 'vegetarisch',
  '52': 'vegan',
  '53': 'Sprint-Menü',
  '55': 'Bio',
  'A!': 'enthält glutenhaltiges Getreide',
  A1: 'enthält Weizengluten',
  A2: 'enthält Roggengluten',
  A3: 'enthält Hafergluten',
  A4: 'enthält Gerstengluten',
  A5: 'enthält Dinkelgluten',
  B: 'enthält Krebstiere',
  C: 'enthält Ei',
  D: 'enthält Erdnüsse',
  E: 'enthält Soja',
  F: 'enthält Milch (einschließlich Laktose)',
  'G!': 'enthält Schalenfrüchte',
  G1: 'enthält Haselnuss',
  G2: 'enthält Mandeln',
  G3: 'enthält Wallnuss',
  G4: 'enthält Cashewkerne',
  G5: 'enthält Pecannüsse',
  G6: 'enthält Pistazien',
  G7: 'enthält Macadamianuss',
  H: 'enthält Sellerie',
  I: 'enthält Senf',
  J: 'enthält Sesam',
  K: 'enthält Schwefeldioxid/Sulfite (10 mg/kg)',
  L: 'enthält Lupine',
  M: 'enthält Weichtiere',
  N: 'enthält Fisch',
};

const labels = new Map(Object.entries(UPSTREAM_LABELS));

function classify(codes: string[], isSprint = false) {
  return classifyMeal({ ingredientCodes: codes, isSprint, labelByCode: labels });
}

describe('meal semantics', () => {
  describe('traits', () => {
    it('reads the source markers for vegetarian, vegan and meatless', () => {
      expect(classify(['51']).traits).toEqual(['vegetarian']);
      expect(classify(['52']).traits).toEqual(['vegan']);
      expect(classify(['50']).traits).toEqual(['meatless']);
    });

    it('takes the sprint menu from the plan entry, not from a code', () => {
      expect(classify([], true).traits).toEqual(['sprint']);
      expect(classify(['53']).traits).toEqual([]);
    });

    it('does not infer one trait from another', () => {
      // A vegan dish is vegetarian in real life, but the source marks both when
      // it means both. Inventing the implication would put dishes into filters
      // the kitchen never claimed them for.
      expect(classify(['52']).traits).not.toContain('vegetarian');
    });

    it('keeps the declared order stable', () => {
      const traits = classify(['52', '51', '50'], true).traits;
      expect(traits).toEqual([...MEAL_TRAITS].filter((t) => traits.includes(t)));
    });
  });

  describe('allergens', () => {
    it('maps every allergen the source declares', () => {
      expect(classify(['B']).allergens).toEqual(['crustaceans']);
      expect(classify(['C']).allergens).toEqual(['egg']);
      expect(classify(['D']).allergens).toEqual(['peanuts']);
      expect(classify(['E']).allergens).toEqual(['soy']);
      expect(classify(['F']).allergens).toEqual(['milk']);
      expect(classify(['H']).allergens).toEqual(['celery']);
      expect(classify(['I']).allergens).toEqual(['mustard']);
      expect(classify(['J']).allergens).toEqual(['sesame']);
      expect(classify(['K']).allergens).toEqual(['sulphites']);
      expect(classify(['L']).allergens).toEqual(['lupin']);
      expect(classify(['M']).allergens).toEqual(['molluscs']);
      expect(classify(['N']).allergens).toEqual(['fish']);
    });

    it('derives the gluten parent from any cereal', () => {
      // Somebody avoiding gluten must not have to know that "A3" is oats.
      expect(classify(['A1']).allergens).toEqual(['gluten', 'gluten_wheat']);
      expect(classify(['A2']).allergens).toEqual(['gluten', 'gluten_rye']);
      expect(classify(['A3']).allergens).toEqual(['gluten', 'gluten_oats']);
      expect(classify(['A4']).allergens).toEqual(['gluten', 'gluten_barley']);
      expect(classify(['A5']).allergens).toEqual(['gluten', 'gluten_spelt']);
    });

    it('derives the nut parent from any nut', () => {
      expect(classify(['G1']).allergens).toEqual(['nuts', 'nuts_hazelnut']);
      expect(classify(['G7']).allergens).toEqual(['nuts', 'nuts_macadamia']);
    });

    it('keeps the parent on its own when the source only declares it', () => {
      expect(classify(['A!']).allergens).toEqual(['gluten']);
      expect(classify(['G!']).allergens).toEqual(['nuts']);
    });

    it('reports each allergen once, however often it is declared', () => {
      expect(classify(['A1', 'A!', 'A1']).allergens).toEqual(['gluten', 'gluten_wheat']);
    });

    it('orders allergens by the published taxonomy, not by the source', () => {
      const allergens = classify(['N', 'C', 'A1']).allergens;
      expect(allergens).toEqual([...MEAL_ALLERGENS].filter((a) => allergens.includes(a)));
    });
  });

  describe('what it refuses to guess', () => {
    it('leaves additives and meat categories unmapped', () => {
      // "Fisch" as a meat category is not the declared allergen "enthält Fisch",
      // and a dish is not suddenly an allergy risk because it contains pork.
      const result = classify(['1', '2', '45', '46', '47', '48', '49', '55']);
      expect(result.allergens).toEqual([]);
      expect(result.traits).toEqual([]);
    });

    it('ignores a code it has never seen', () => {
      // An unknown code stays a plain source marker elsewhere; it never gets an
      // invented semantic key.
      expect(classify(['9999', 'Z9']).allergens).toEqual([]);
      expect(classify(['9999', 'Z9']).traits).toEqual([]);
    });
  });

  describe('falling back to the label', () => {
    it('recognises a known allergen under a new code', () => {
      // Upstream renumbering must not silently empty everybody's filters.
      const renamed = new Map([['XX9', 'enthält Erdnüsse']]);
      expect(
        classifyMeal({ ingredientCodes: ['XX9'], isSprint: false, labelByCode: renamed }).allergens,
      ).toEqual(['peanuts']);
    });

    it('is insensitive to case, umlauts, punctuation and spacing', () => {
      const variants = new Map([
        ['X1', '  ENTHÄLT   SCHALENFRÜCHTE '],
        ['X2', 'Enthaelt Weizengluten'],
        ['X3', 'enthält Milch'],
        ['X4', 'enthält Schwefeldioxid/Sulfite'],
      ]);
      const result = classifyMeal({
        ingredientCodes: ['X1', 'X2', 'X3', 'X4'],
        isSprint: false,
        labelByCode: variants,
      });
      expect(result.allergens).toEqual(['gluten', 'gluten_wheat', 'milk', 'nuts', 'sulphites']);
    });

    it('strips diacritics the German folding does not cover', () => {
      const accented = new Map([['X1', 'enthält Séllerie']]);
      expect(
        classifyMeal({ ingredientCodes: ['X1'], isSprint: false, labelByCode: accented }).allergens,
      ).toEqual(['celery']);
    });

    it('accepts the common spelling of walnut and pecan either way', () => {
      // The source writes "Wallnuss" and "Pecannüsse"; both spellings are real.
      const spellings = new Map([
        ['X1', 'enthält Walnuss'],
        ['X2', 'enthält Pekannüsse'],
      ]);
      expect(
        classifyMeal({ ingredientCodes: ['X1', 'X2'], isSprint: false, labelByCode: spellings })
          .allergens,
      ).toEqual(['nuts', 'nuts_walnut', 'nuts_pecan']);
    });

    it('does not need labels at all when the codes are the known ones', () => {
      expect(classifyMeal({ ingredientCodes: ['A1', '52'], isSprint: false }).allergens).toEqual([
        'gluten',
        'gluten_wheat',
      ]);
      expect(classifyMeal({ ingredientCodes: ['A1', '52'], isSprint: false }).traits).toEqual([
        'vegan',
      ]);
    });
  });

  it('covers the whole published taxonomy', () => {
    // Every key the app offers as a filter must be reachable from real data —
    // a filter that can never match anything is worse than no filter.
    const reachable = new Set<string>();
    for (const code of Object.keys(UPSTREAM_LABELS)) {
      for (const allergen of classify([code]).allergens) {
        reachable.add(allergen);
      }
      for (const trait of classify([code]).traits) {
        reachable.add(trait);
      }
    }
    reachable.add('sprint');

    expect([...MEAL_ALLERGENS].filter((key) => !reachable.has(key))).toEqual([]);
    expect([...MEAL_TRAITS].filter((key) => !reachable.has(key))).toEqual([]);
  });
});
