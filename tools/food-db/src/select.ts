export type PortionRow = {
  description: string;
  gramWeight: number;
};

export type FoodRow = {
  fdcId: number;
  description: string;
  category: string;
  portions: PortionRow[];
  nutrients: Map<number, number>;
};

export type SelectedFood = {
  fdcId: number;
  name: string;
  aliases: string[];
  servingDescription: string;
  gramsPerServing: number;
  caloriesPerServing: number | null;
  proteinPerServing: number | null;
  fatPerServing: number | null;
  carbsPerServing: number | null;
  saturatedFatPerServing: number | null;
  fiberPerServing: number | null;
  sugarsPerServing: number | null;
  addedSugarsPerServing: number | null;
  sodiumPerServing: number | null;
  cholesterolPerServing: number | null;
};

const nutrientIds = {
  caloriesPerServing: 1008,
  proteinPerServing: 1003,
  fatPerServing: 1004,
  carbsPerServing: 1005,
  saturatedFatPerServing: 1258,
  fiberPerServing: 1079,
  sugarsPerServing: 2000,
  addedSugarsPerServing: 1235,
  sodiumPerServing: 1093,
  cholesterolPerServing: 1253,
} as const;

const excludedName = /\b(?:infant|baby food|formula|nfs|ns as to)\b/i;

const preferredPortions = [
  /\bmedium\b/i,
  /\b\d+\s+(?:banana|apple|egg|orange|pear|potato|sweet potato)\b/i,
  /\begg\b/i,
  /\bfillet\b/i,
  /\bsteak\b/i,
  /\b\d+(?:\.\d+)?\s+oz\b/i,
  /\btablespoon\b/i,
  /\bteaspoon\b/i,
  /\bcup\b/i,
  /\bslice\b/i,
  /\bpiece\b/i,
  /\bsection\/slice\b/i,
];

const alcoholName = /\b(?:alcoholic|vodka|whiskey|whisky|rum|gin|tequila|liqueur|wine|beer)\b/i;

export function choosePortion(portions: PortionRow[]): { description: string; grams: number } {
  const eligible = portions.filter(({ gramWeight }) =>
    Number.isFinite(gramWeight) && gramWeight > 0 && gramWeight <= 1000
  );

  const selected = preferredPortions
    .flatMap((preference) => {
      const matching = eligible.find(({ description }) => preference.test(description));

      return matching ? [matching] : [];
    })[0] ?? eligible[0];

  return selected
    ? { description: selected.description.trim(), grams: selected.gramWeight }
    : { description: "100 g", grams: 100 };
}

export function friendlyName(description: string): string {
  const withoutSource = description
    .replace(/,\s*from (?:fast food\s*\/\s*restaurant|other sources|precooked|raw)\b.*$/i, "")
    .replace(/\([^)]*\)/g, " ")
    .replace(/["“”]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  const parts = withoutSource.split(",").map((part) => part.trim()).filter(Boolean);
  const secondPart = parts[1]?.toLowerCase();
  const preparation = /^(?:raw|cooked|grilled|roasted|baked|boiled|fried|steamed|broiled|microwaved|as purchased|with|without|from|made with|no added fat)\b/i;
  const genericFood = /^(?:chicken|beef|pork|fish|potato|potatoes|rice|beans|coffee|milk|tea|pasta|noodles|bread|cereal|soup|salad)$/i;

  const name = secondPart && preparation.test(secondPart) && genericFood.test(parts[0] ?? "")
    ? `${parts[1]} ${parts[0]}`
    : secondPart && !preparation.test(secondPart)
    ? parts.slice(0, 2).join(", ")
    : parts[0] ?? "";

  return name
    .split(" ")
    .map((word) => word[0]!.toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

export function selectFoods(rows: FoodRow[], minimum = 2500): SelectedFood[] {
  const selectedByName = new Map<string, { row: FoodRow; name: string }>();

  for (const row of rows) {
    if (excludedName.test(row.description) || excludedName.test(row.category)) continue;

    if (alcoholName.test(row.description) && (row.nutrients.get(1003) ?? 0) === 0) continue;

    if ([1008, 1003, 1004, 1005].some((id) => !row.nutrients.has(id))) continue;
    const name = friendlyName(row.description);

    if (name.length < 2) continue;
    const key = name.toLowerCase();
    const candidate = selectedByName.get(key);

    if (!candidate || row.fdcId < candidate.row.fdcId) selectedByName.set(key, { row, name });
  }

  const candidates = Array.from(selectedByName.values(), ({ row, name }) => ({
    row,
    name,
    priority: row.description.split(",").length * 10 + row.description.split(/\s+/).length,
  })).sort((left, right) => left.priority - right.priority || left.row.fdcId - right.row.fdcId);

  const selected = candidates.slice(0, 3300).map(({ row, name }) => {
    const portion = choosePortion(row.portions);

    const per100g = (id: number): number | null => {
      const value = row.nutrients.get(id);

      return value === undefined ? null : round(value * portion.grams / 100);
    };

    return {
      fdcId: row.fdcId,
      name,
      aliases: [row.description],
      servingDescription: portion.description,
      gramsPerServing: round(portion.grams),
      caloriesPerServing: per100g(nutrientIds.caloriesPerServing),
      proteinPerServing: per100g(nutrientIds.proteinPerServing),
      fatPerServing: per100g(nutrientIds.fatPerServing),
      carbsPerServing: per100g(nutrientIds.carbsPerServing),
      saturatedFatPerServing: per100g(nutrientIds.saturatedFatPerServing),
      fiberPerServing: per100g(nutrientIds.fiberPerServing),
      sugarsPerServing: per100g(nutrientIds.sugarsPerServing),
      addedSugarsPerServing: per100g(nutrientIds.addedSugarsPerServing),
      sodiumPerServing: per100g(nutrientIds.sodiumPerServing),
      cholesterolPerServing: per100g(nutrientIds.cholesterolPerServing),
    } satisfies SelectedFood;
  });

  if (selected.length < minimum || selected.length > 3500) {
    throw new Error(`Expected 2,500–3,500 foods, selected ${selected.length}.`);
  }

  return selected.sort((left, right) => left.name < right.name ? -1 : left.name > right.name ? 1 : left.fdcId - right.fdcId);
}

function round(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}
