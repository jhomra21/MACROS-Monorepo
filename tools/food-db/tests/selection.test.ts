import { describe, expect, test } from "bun:test";
import { choosePortion, friendlyName, selectFoods, type FoodRow } from "../src/select";

const baseFood = (overrides: Partial<FoodRow> = {}): FoodRow => ({
  fdcId: 1,
  description: "Chicken breast, grilled",
  category: "Poultry",
  portions: [],
  nutrients: new Map([[1008, 165], [1003, 31], [1004, 3.6], [1005, 0]]),
  ...overrides,
});

describe("FNDDS food selection", () => {
  test("preserves missing nutrients as null and keeps zero-calorie foods", () => {
    const foods = selectFoods([
      baseFood({
        fdcId: 1,
        description: "Zero calorie food",
        nutrients: new Map([[1008, 0], [1003, 0], [1004, 0], [1005, 0]]),
      }),
      baseFood({ fdcId: 2, description: "Missing fiber", nutrients: new Map([[1008, 20], [1003, 1], [1004, 1], [1005, 1]]) }),
    ], 0);

    expect(foods.find(({ aliases }) => aliases[0] === "Zero calorie food")?.caloriesPerServing).toBe(0);
    expect(foods.find(({ aliases }) => aliases[0] === "Missing fiber")?.fiberPerServing).toBeNull();
  });

  test("prefers natural servings before cups and uses source gram weights", () => {
    const portion = choosePortion([
      { description: "1 cup", gramWeight: 0 },
      { description: "1 cup mashed", gramWeight: 225 },
      { description: "1 medium", gramWeight: 118 },
      { description: "1 oz", gramWeight: 28.3495 },
      { description: "100 g", gramWeight: 100 },
    ]);

    expect(portion).toEqual({ description: "1 medium", grams: 118 });
    expect(choosePortion([{ description: "1 cup", gramWeight: 240 }, { description: "1 oz", gramWeight: 28.3495 }]))
      .toEqual({ description: "1 oz", grams: 28.3495 });
    expect(choosePortion([{ description: "1 cup, mashed", gramWeight: 225 }, { description: "1 banana", gramWeight: 126 }]))
      .toEqual({ description: "1 banana", grams: 126 });
    expect(choosePortion([])).toEqual({ description: "100 g", grams: 100 });
  });

  test("excludes NFS duplicates, infants, and alcohol-only foods", () => {
    const selected = selectFoods([
      baseFood({ fdcId: 1, description: "Chicken breast, grilled" }),
      baseFood({ fdcId: 2, description: "Chicken breast, grilled, NS as to preparation" }),
      baseFood({ fdcId: 3, description: "Infant formula, ready to feed", category: "Baby Foods" }),
      baseFood({ fdcId: 4, description: "Vodka, plain", nutrients: new Map([[1008, 231]]) }),
    ], 0);

    expect(selected.map(({ aliases }) => aliases[0])).toEqual(["Chicken breast, grilled"]);
  });

  test("deduplicates friendly names deterministically and keeps UTF-8 aliases", () => {
    const selected = selectFoods([
      baseFood({ fdcId: 9, description: "Crème brûlée" }),
      baseFood({ fdcId: 3, description: "Crème brûlée" }),
    ], 0);

    expect(selected).toHaveLength(1);
    expect(selected[0]?.aliases).toContain("Crème brûlée");
    expect(friendlyName("chicken breast, grilled")).toBe("Chicken Breast");
    expect(friendlyName("rice, white, cooked, no added fat")).toBe("Rice, White");
  });
});
