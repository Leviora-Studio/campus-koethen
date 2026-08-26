/**
 * Stable semantic keys for what a dish is and what it contains.
 *
 * The source publishes its own code namespace (`A1`, `G!`, `52`, …) with German
 * labels. Those codes are the source's business: they mix two namespaces, they
 * are not documented anywhere, and a client filtering on them would break the
 * moment the canteen software renumbers something. So the mapping happens here,
 * once, and the app only ever sees the keys below.
 *
 * Two rules govern every entry in this file:
 *
 *  * **Nothing is invented.** A key exists only where the source genuinely
 *    declares the property. An unknown code gets no key at all and stays a
 *    plain marker in the response — visible, but not filterable.
 *  * **Nothing is inferred beyond the declared hierarchy.** The two parent
 *    facets (gluten, nuts) are derived from their subtypes because the source
 *    itself models them that way. A vegan dish is *not* silently made
 *    vegetarian: the kitchen marks both when it means both, and a filter is a
 *    promise about what was declared.
 */

export const MEAL_TRAITS = ['vegetarian', 'vegan', 'meatless', 'sprint'] as const;
export type MealTrait = (typeof MEAL_TRAITS)[number];

/**
 * The allergen taxonomy, parents immediately followed by their subtypes. The
 * order is the published one and is what the API sorts by, so two identical
 * dishes never differ by the order the source happened to list their codes in.
 */
export const MEAL_ALLERGENS = [
  'gluten',
  'gluten_wheat',
  'gluten_rye',
  'gluten_oats',
  'gluten_barley',
  'gluten_spelt',
  'crustaceans',
  'egg',
  'peanuts',
  'soy',
  'milk',
  'nuts',
  'nuts_hazelnut',
  'nuts_almond',
  'nuts_walnut',
  'nuts_cashew',
  'nuts_pecan',
  'nuts_pistachio',
  'nuts_macadamia',
  'celery',
  'mustard',
  'sesame',
  'sulphites',
  'lupin',
  'molluscs',
  'fish',
] as const;
export type MealAllergen = (typeof MEAL_ALLERGENS)[number];

/** Which parent a subtype belongs to. */
const ALLERGEN_PARENT: Partial<Record<MealAllergen, MealAllergen>> = {
  gluten_wheat: 'gluten',
  gluten_rye: 'gluten',
  gluten_oats: 'gluten',
  gluten_barley: 'gluten',
  gluten_spelt: 'gluten',
  nuts_hazelnut: 'nuts',
  nuts_almond: 'nuts',
  nuts_walnut: 'nuts',
  nuts_cashew: 'nuts',
  nuts_pecan: 'nuts',
  nuts_pistachio: 'nuts',
  nuts_macadamia: 'nuts',
};

/**
 * The source codes as observed on `meine-mensa.de` for the Köthen locations.
 *
 * Deliberately absent: the meat categories (`45` Schwein … `49` Wild, `56`
 * Lamm) and the additive numbers. "Fisch" as a meat category is a different
 * statement from the declared allergen "enthält Fisch", and a dish does not
 * become an allergy risk because it contains pork.
 */
const CODE_TO_ALLERGEN: Readonly<Record<string, MealAllergen>> = {
  'A!': 'gluten',
  A1: 'gluten_wheat',
  A2: 'gluten_rye',
  A3: 'gluten_oats',
  A4: 'gluten_barley',
  A5: 'gluten_spelt',
  B: 'crustaceans',
  C: 'egg',
  D: 'peanuts',
  E: 'soy',
  F: 'milk',
  'G!': 'nuts',
  G1: 'nuts_hazelnut',
  G2: 'nuts_almond',
  G3: 'nuts_walnut',
  G4: 'nuts_cashew',
  G5: 'nuts_pecan',
  G6: 'nuts_pistachio',
  G7: 'nuts_macadamia',
  H: 'celery',
  I: 'mustard',
  J: 'sesame',
  K: 'sulphites',
  L: 'lupin',
  M: 'molluscs',
  N: 'fish',
};

const CODE_TO_TRAIT: Readonly<Record<string, MealTrait>> = {
  '50': 'meatless',
  '51': 'vegetarian',
  '52': 'vegan',
  // "53" is the source's Sprint marker. The trait comes from the plan entry's
  // `is_sprint` flag instead, which is where the source states it per serving.
};

/**
 * Labels, normalised, as the second way in.
 *
 * The codes above are the primary key; this table catches the case where the
 * source renumbers a code but keeps calling it the same thing. Every entry is
 * an actually observed label or a spelling of it that a human would write —
 * "Wallnuss" is what the source writes today, "Walnuss" is what it means.
 */
const LABEL_TO_ALLERGEN: Readonly<Record<string, MealAllergen>> = {
  'enthaelt glutenhaltiges getreide': 'gluten',
  'enthaelt weizengluten': 'gluten_wheat',
  'enthaelt roggengluten': 'gluten_rye',
  'enthaelt hafergluten': 'gluten_oats',
  'enthaelt gerstengluten': 'gluten_barley',
  'enthaelt dinkelgluten': 'gluten_spelt',
  'enthaelt krebstiere': 'crustaceans',
  'enthaelt ei': 'egg',
  'enthaelt erdnuesse': 'peanuts',
  'enthaelt soja': 'soy',
  'enthaelt milch': 'milk',
  'enthaelt milch einschliesslich laktose': 'milk',
  'enthaelt schalenfruechte': 'nuts',
  'enthaelt haselnuss': 'nuts_hazelnut',
  'enthaelt mandeln': 'nuts_almond',
  'enthaelt walnuss': 'nuts_walnut',
  'enthaelt wallnuss': 'nuts_walnut',
  'enthaelt cashewkerne': 'nuts_cashew',
  'enthaelt pekannuesse': 'nuts_pecan',
  'enthaelt pecannuesse': 'nuts_pecan',
  'enthaelt pistazien': 'nuts_pistachio',
  'enthaelt macadamianuss': 'nuts_macadamia',
  'enthaelt sellerie': 'celery',
  'enthaelt senf': 'mustard',
  'enthaelt sesam': 'sesame',
  'enthaelt schwefeldioxid sulfite': 'sulphites',
  'enthaelt schwefeldioxid sulfite 10 mg kg': 'sulphites',
  'enthaelt lupine': 'lupin',
  'enthaelt weichtiere': 'molluscs',
  'enthaelt fisch': 'fish',
};

const LABEL_TO_TRAIT: Readonly<Record<string, MealTrait>> = {
  fleischlos: 'meatless',
  vegetarisch: 'vegetarian',
  vegan: 'vegan',
};

const normalizedLabelCache = new Map<string, string>();
const MAX_NORMALIZED_LABEL_CACHE = 1_000;

/**
 * Folds a German source label to a comparable form: lower case, umlauts and ß
 * spelled out, remaining diacritics dropped, everything that is not a letter or
 * a digit turned into a single space.
 */
export function normalizeSourceLabel(label: string): string {
  const cached = normalizedLabelCache.get(label);
  if (cached !== undefined) {
    return cached;
  }
  const normalized = label
    .toLowerCase()
    .replace(/ä/g, 'ae')
    .replace(/ö/g, 'oe')
    .replace(/ü/g, 'ue')
    .replace(/ß/g, 'ss')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

  if (normalizedLabelCache.size >= MAX_NORMALIZED_LABEL_CACHE) {
    const first = normalizedLabelCache.keys().next();
    if (!first.done) normalizedLabelCache.delete(first.value);
  }
  normalizedLabelCache.set(label, normalized);
  return normalized;
}

export interface MealSemantics {
  traits: MealTrait[];
  allergens: MealAllergen[];
}

export interface ClassifyMealInput {
  ingredientCodes: string[];
  isSprint: boolean;
  /** The source's `code -> German label` dictionary, when it is available. */
  labelByCode?: ReadonlyMap<string, string>;
}

/**
 * Turns one dish's source codes into the published semantic keys.
 *
 * Pure and total: an unknown code contributes nothing, and no input can make
 * this throw. The caller keeps the raw markers regardless, so nothing the
 * source said is lost on the way to the client.
 */
export function classifyMeal(input: ClassifyMealInput): MealSemantics {
  const traits = new Set<MealTrait>();
  const allergens = new Set<MealAllergen>();

  for (const rawCode of input.ingredientCodes) {
    const code = rawCode.trim();
    if (code.length === 0) continue;

    const allergen =
      CODE_TO_ALLERGEN[code] ?? lookupByLabel(LABEL_TO_ALLERGEN, code, input.labelByCode);
    if (allergen) {
      allergens.add(allergen);
      const parent = ALLERGEN_PARENT[allergen];
      // Somebody avoiding gluten must not have to know that "A3" is oats.
      if (parent) allergens.add(parent);
      continue;
    }

    const trait = CODE_TO_TRAIT[code] ?? lookupByLabel(LABEL_TO_TRAIT, code, input.labelByCode);
    if (trait) traits.add(trait);
  }

  if (input.isSprint) traits.add('sprint');

  // Sorted by the published taxonomy, so two identical dishes never differ by
  // the order the source happened to list their codes in.
  return {
    traits: MEAL_TRAITS.filter((trait) => traits.has(trait)),
    allergens: MEAL_ALLERGENS.filter((allergen) => allergens.has(allergen)),
  };
}

function lookupByLabel<T>(
  table: Readonly<Record<string, T>>,
  code: string,
  labelByCode?: ReadonlyMap<string, string>,
): T | undefined {
  const label = labelByCode?.get(code);
  if (label === undefined) return undefined;
  return table[normalizeSourceLabel(label)];
}
