import { Prisma } from '../../generated/prisma/client';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { CanteenSyncService } from './canteen-sync.service';
import { MeineMensaClient } from './meine-mensa.client';
import { NormalizedMeal } from './meine-mensa.schema';

type Definition = { code: string; labelDe: string; kind: 'ingredient' | 'marker' };

/** A dish as the source publishes it. */
function meal(sourcePlanId: number, over: Partial<NormalizedMeal> = {}): NormalizedMeal {
  return {
    sourcePlanId,
    sourceFoodId: sourcePlanId + 1,
    date: '2026-08-06',
    counterId: 1,
    isSprint: false,
    name: `Gericht ${sourcePlanId}`,
    subtitle: null,
    extras: [],
    ingredientCodes: [],
    prices: [{ group: 'student', amount: '2.00' }],
    ...over,
  };
}

/** The row that dish would already be stored as. */
function storedMeal(next: NormalizedMeal, over: Record<string, unknown> = {}) {
  return {
    id: `meal-${next.sourcePlanId}`,
    sourcePlanId: next.sourcePlanId,
    source: 'meine-mensa',
    canteenId: 'canteen-id',
    date: new Date(`${next.date}T00:00:00.000Z`),
    counterId: next.counterId,
    isSprint: next.isSprint,
    name: next.name,
    subtitle: next.subtitle,
    extras: next.extras,
    ingredientCodes: next.ingredientCodes,
    sourceFoodId: next.sourceFoodId,
    prices: next.prices.map((price) => ({
      group: price.group,
      // Decimal(6,2) round-trips "2.00" as "2" — the comparison has to survive
      // that, so the double is a real Decimal rather than a string.
      amount: new Prisma.Decimal(price.amount),
    })),
    ...over,
  };
}

function harness(
  options: {
    storedMeals?: ReturnType<typeof storedMeal>[];
    storedDefinitions?: Definition[];
  } = {},
) {
  const tx = {
    ingredientDefinition: {
      findMany: jest.fn().mockResolvedValue(options.storedDefinitions ?? []),
      createMany: jest.fn().mockResolvedValue({ count: 0 }),
      update: jest.fn(),
    },
    meal: {
      findMany: jest.fn().mockResolvedValue(options.storedMeals ?? []),
      createManyAndReturn: jest.fn(async ({ data }: { data: Array<{ sourcePlanId: number }> }) =>
        data.map((row) => ({ id: `meal-${row.sourcePlanId}`, sourcePlanId: row.sourcePlanId })),
      ),
      update: jest.fn(),
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
    mealPrice: {
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      createMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
  };
  const prisma = {
    $transaction: jest.fn(async (operation: (transaction: typeof tx) => Promise<number>) =>
      operation(tx),
    ),
  } as unknown as PrismaService;

  const service = new CanteenSyncService(prisma, {} as MeineMensaClient, {} as Env) as unknown as {
    persist: (
      canteenId: string,
      meals: NormalizedMeal[],
      definitions: Definition[],
    ) => Promise<number>;
  };

  return { service, tx };
}

describe('CanteenSyncService persistence boundary', () => {
  it('withdraws only meals owned by the meine-mensa source', async () => {
    const { service, tx } = harness();

    await service.persist('canteen-id', [meal(123)], []);

    expect(tx.meal.deleteMany).toHaveBeenCalledWith({
      where: expect.objectContaining({ source: 'meine-mensa' }),
    });
  });

  it('leaves an unchanged dictionary entry alone instead of rewriting it', async () => {
    const { service, tx } = harness({
      storedDefinitions: [{ code: '52', labelDe: 'vegan', kind: 'ingredient' }],
    });

    await service.persist(
      'canteen-id',
      [meal(123, { ingredientCodes: ['52'] })],
      [
        { code: '52', labelDe: 'vegan', kind: 'ingredient' },
        { code: '53', labelDe: 'Sprint-Menü', kind: 'marker' },
      ],
    );

    expect(tx.ingredientDefinition.createMany).toHaveBeenCalledWith({
      data: [{ code: '53', labelDe: 'Sprint-Menü', kind: 'marker' }],
    });
    expect(tx.ingredientDefinition.update).not.toHaveBeenCalled();
  });

  /**
   * Cost contract of the write phase.
   *
   * A fortnight of menus across several counters is a few hundred dishes, and
   * every round-trip is taken while the transaction holds its locks. The same
   * per-row pattern is what pushed the timetable import past Prisma's 5s
   * interactive-transaction limit on real data.
   */
  it('inserts a whole new fortnight in one statement', async () => {
    const meals = Array.from({ length: 200 }, (_, index) => meal(1000 + index));
    const definitions = Array.from({ length: 60 }, (_, index) => ({
      code: `code-${index}`,
      labelDe: `Label ${index}`,
      kind: 'ingredient' as const,
    }));
    const { service, tx } = harness();

    await service.persist('canteen-id', meals, definitions);

    expect(tx.meal.createManyAndReturn).toHaveBeenCalledTimes(1);
    expect(tx.meal.update).not.toHaveBeenCalled();
    // Nothing to clear: a dish that did not exist has no prices.
    expect(tx.mealPrice.deleteMany).not.toHaveBeenCalled();
    expect(tx.mealPrice.createMany).toHaveBeenCalledTimes(1);
    expect(tx.mealPrice.createMany).toHaveBeenCalledWith({
      data: expect.arrayContaining([{ mealId: 'meal-1000', group: 'student', amount: '2.00' }]),
    });

    // One read of the dictionary and one insert, not one upsert per code.
    expect(tx.ingredientDefinition.findMany).toHaveBeenCalledTimes(1);
    expect(tx.ingredientDefinition.createMany).toHaveBeenCalledTimes(1);
    expect(tx.ingredientDefinition.update).not.toHaveBeenCalled();
  });

  it('writes nothing when the source republishes the same fortnight', async () => {
    // The real case: the plan is fetched every two hours and does not move.
    const meals = Array.from({ length: 200 }, (_, index) => meal(1000 + index));
    const { service, tx } = harness({ storedMeals: meals.map((entry) => storedMeal(entry)) });

    await service.persist('canteen-id', meals, []);

    expect(tx.meal.createManyAndReturn).not.toHaveBeenCalled();
    expect(tx.meal.update).not.toHaveBeenCalled();
    expect(tx.mealPrice.deleteMany).not.toHaveBeenCalled();
    expect(tx.mealPrice.createMany).not.toHaveBeenCalled();
  });

  it('writes one row for the dish that changed and leaves the rest alone', async () => {
    const meals = Array.from({ length: 200 }, (_, index) => meal(1000 + index));
    const stored = meals.map((entry) => storedMeal(entry));
    const { service, tx } = harness({ storedMeals: stored });

    meals[42] = meal(1042, { name: 'Gemüsepfanne (neu)' });

    await service.persist('canteen-id', meals, []);

    expect(tx.meal.update).toHaveBeenCalledTimes(1);
    expect(tx.meal.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'meal-1042' },
        data: expect.objectContaining({ name: 'Gemüsepfanne (neu)' }),
      }),
    );
    // Its prices did not move, so they are not rewritten either.
    expect(tx.mealPrice.deleteMany).not.toHaveBeenCalled();
    expect(tx.mealPrice.createMany).not.toHaveBeenCalled();
  });

  it('replaces the prices of exactly the dish whose prices moved', async () => {
    const meals = [meal(1000), meal(1001), meal(1002)];
    const stored = meals.map((entry) => storedMeal(entry));
    const { service, tx } = harness({ storedMeals: stored });

    // The employee price appeared; student stayed the same.
    meals[1] = meal(1001, {
      prices: [
        { group: 'student', amount: '2.00' },
        { group: 'employee', amount: '4.95' },
      ],
    });

    await service.persist('canteen-id', meals, []);

    expect(tx.mealPrice.deleteMany).toHaveBeenCalledWith({
      where: { mealId: { in: ['meal-1001'] } },
    });
    expect(tx.mealPrice.createMany).toHaveBeenCalledWith({
      data: [
        { mealId: 'meal-1001', group: 'student', amount: '2.00' },
        { mealId: 'meal-1001', group: 'employee', amount: '4.95' },
      ],
    });
  });

  it('takes over a row of another source with the same plan id, as the upsert did', async () => {
    // The write used to match on sourcePlanId alone and set `source` along
    // with the rest, so a row seeded by the user-test data was adopted rather
    // than colliding. Treating it as unchanged would leave it mislabelled;
    // treating it as new would violate the unique constraint.
    const entry = meal(1000);
    const { service, tx } = harness({
      storedMeals: [storedMeal(entry, { source: 'user-test-data' })],
    });

    await service.persist('canteen-id', [entry], []);

    expect(tx.meal.createManyAndReturn).not.toHaveBeenCalled();
    expect(tx.meal.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'meal-1000' },
        data: expect.objectContaining({ source: 'meine-mensa' }),
      }),
    );
  });

  it('rewrites a dish that moved to another canteen', async () => {
    const entry = meal(1000);
    const { service, tx } = harness({
      storedMeals: [storedMeal(entry, { canteenId: 'other-canteen' })],
    });

    await service.persist('canteen-id', [entry], []);

    expect(tx.meal.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ canteenId: 'canteen-id' }) }),
    );
  });
});
