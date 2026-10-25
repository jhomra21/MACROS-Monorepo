import { describe, expect, test } from "bun:test";
import { choosePortion, friendlyName, householdAliases, selectFoods, type FoodRow } from "../src/select";
import { z } from "zod";

const servingFields = [
  "servingDescription",
  "gramsPerServing",
  "caloriesPerServing",
  "proteinPerServing",
  "fatPerServing",
  "carbsPerServing",
  "saturatedFatPerServing",
  "fiberPerServing",
  "sugarsPerServing",
  "addedSugarsPerServing",
  "sodiumPerServing",
  "cholesterolPerServing",
] as const;

const legacyFoodFixtureSchema = z.object({
  name: z.string(),
  servingDescription: z.string(),
  gramsPerServing: z.number(),
  caloriesPerServing: z.number(),
  proteinPerServing: z.number(),
  fatPerServing: z.number(),
  carbsPerServing: z.number(),
  saturatedFatPerServing: z.number().nullable(),
  fiberPerServing: z.number().nullable(),
  sugarsPerServing: z.number().nullable(),
  addedSugarsPerServing: z.number().nullable(),
  sodiumPerServing: z.number().nullable(),
  cholesterolPerServing: z.number().nullable(),
});

const bundledFoodFixtureSchema = legacyFoodFixtureSchema.extend({
  aliases: z.array(z.string()),
});

const baseFood = (overrides: Partial<FoodRow> = {}): FoodRow => ({
  fdcId: 1,
  description: "Chicken breast, grilled",
  category: "Poultry",
  portions: [],
  nutrients: new Map([[1008, 165], [1003, 31], [1004, 3.6], [1005, 0]]),
  ...overrides,
});

describe("FNDDS food selection", () => {
  test("bundled legacy foods retain exact serving fields from the legacy fixture", async () => {
    const legacyFoods = z.array(legacyFoodFixtureSchema).parse(
      await Bun.file(new URL("../legacy-foods.json", import.meta.url)).json(),
    );

    const bundledFoods = z.array(bundledFoodFixtureSchema).parse(
      await Bun.file(new URL("../../../cal-macro-tracker/CommonFoods/common_foods.json", import.meta.url)).json(),
    );

    const bundledByName = new Map(bundledFoods.map((food) => [food.name, food]));

    expect(legacyFoods).toHaveLength(12);

    for (const legacyFood of legacyFoods) {
      const bundledFood = bundledByName.get(legacyFood.name);

      expect(bundledFood, legacyFood.name).toBeDefined();
      expect(
        JSON.stringify(Object.fromEntries(servingFields.map((field) => [field, bundledFood?.[field]]))),
        legacyFood.name,
      ).toBe(JSON.stringify(Object.fromEntries(servingFields.map((field) => [field, legacyFood[field]]))));
    }
  });

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

    expect(portion).toEqual({ description: "1 medium", grams: 118, usedFallbackPortion: false });
    expect(choosePortion([{ description: "1 cup", gramWeight: 240 }, { description: "1 oz", gramWeight: 28.3495 }]))
      .toEqual({ description: "1 oz", grams: 28.3495, usedFallbackPortion: false });
    expect(choosePortion([{ description: "1 cup, mashed", gramWeight: 225 }, { description: "1 banana", gramWeight: 126 }]))
      .toEqual({ description: "1 banana", grams: 126, usedFallbackPortion: false });
    expect(choosePortion([{ description: "Quantity not specified", gramWeight: 60 }]))
      .toEqual({ description: "100 g", grams: 100, usedFallbackPortion: true });
    expect(choosePortion([])).toEqual({ description: "100 g", grams: 100, usedFallbackPortion: true });
    expect(selectFoods([baseFood({
      portions: [{ description: "Quantity not specified", gramWeight: 60 }],
    })], 0)[0]).toMatchObject({ servingDescription: "100 g", gramsPerServing: 100 });
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
    expect(friendlyName("chicken breast, grilled")).toBe("Chicken Breast, Grilled");
    expect(friendlyName("rice, white, cooked, no added fat")).toBe("Rice, White, Cooked, No Added Fat");
    expect(friendlyName("beef, ground, raw")).toBe("Beef, Ground, Raw");
    expect(friendlyName("lentils, from dried, fat added")).toBe("Lentils, From Dried, Fat Added");
    expect(friendlyName("chicken, with skin")).toBe("Chicken, With Skin");
    expect(friendlyName("chicken, without skin")).toBe("Chicken, Without Skin");
    expect(friendlyName("tea, sweetened")).toBe("Tea, Sweetened");
    expect(friendlyName("tea, unsweetened")).toBe("Tea, Unsweetened");

    const variants = selectFoods([
      baseFood({ fdcId: 1, description: "Beef, ground, raw" }),
      baseFood({ fdcId: 2, description: "Beef, ground, cooked" }),
      baseFood({ fdcId: 3, description: "Lentils, from dried, fat added" }),
      baseFood({ fdcId: 4, description: "Lentils, from dried, no added fat" }),
    ], 0);

    expect(variants.map(({ name }) => name)).toEqual([
      "Beef, Ground, Cooked",
      "Beef, Ground, Raw",
      "Lentils, From Dried, Fat Added",
      "Lentils, From Dried, No Added Fat",
    ]);
  });

  test("adds deterministic household aliases to matching source descriptions", () => {
    const cases: [string, string[]][] = [
      ["Peppers, sweet, green, raw", ["bell pepper", "sweet pepper"]],
      ["Onions, green, raw", ["scallion", "green onion"]],
      ["Cilantro, raw", ["cilantro", "coriander"]],
      ["Chickpeas, from canned, reduced sodium", ["garbanzo", "chickpea"]],
      ["Zucchini, pickled", ["zucchini", "courgette"]],
      ["Eggplant, raw", ["eggplant", "aubergine"]],
      ["Soft drink, cola", ["soda", "soft drink"]],
      ["Potato, french fries, fast food", ["fries", "french fries"]],
      ["Beef, ground, raw", ["ground beef"]],
      ["Chicken breast, grilled without sauce, skin not eaten", ["chicken breast"]],
    ];

    for (const [description, aliases] of cases) {
      expect(householdAliases(description), description).toEqual(aliases);
    }

    expect(householdAliases("green pepper, cooked")).toEqual([]);
    expect(selectFoods([baseFood({ description: "Peppers, sweet, green, raw" })], 0)[0]?.aliases)
      .toContain("bell pepper");
  });
});
