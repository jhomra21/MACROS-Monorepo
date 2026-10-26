import { z } from "zod";

export const stapleSchema = z.object({
  query: z.string().trim().min(1),
  name: z.string().trim().min(1),
});

export type Staple = z.infer<typeof stapleSchema>;

export function validateStaples(staples: Staple[], foods: { name: string }[]): Staple[] {
  const names = new Set(foods.map(({ name }) => name));
  const queries = new Set<string>();

  for (const staple of staples) {
    const normalizedQuery = staple.query.toLocaleLowerCase("en-US");

    if (queries.has(normalizedQuery)) {
      throw new Error(`Duplicate staple query "${staple.query}".`);
    }

    queries.add(normalizedQuery);

    if (!names.has(staple.name)) {
      throw new Error(`Staple "${staple.query}" targets missing food "${staple.name}".`);
    }
  }

  return staples;
}

export function stapleNamesInPriorityOrder(staples: Staple[]): string[] {
  return [...new Set(staples.map(({ name }) => name))];
}

export function addStapleAliases(staples: Staple[], foods: { name: string; aliases: string[] }[]) {
  const queriesByName = new Map<string, string[]>();

  for (const { query, name } of staples) {
    const queries = queriesByName.get(name) ?? [];
    queries.push(query);
    queriesByName.set(name, queries);
  }

  return foods.map((food) => {
    const stapleQueries = queriesByName.get(food.name);

    return stapleQueries
      ? { ...food, aliases: [...new Set([...food.aliases, ...stapleQueries])] }
      : food;
  });
}
