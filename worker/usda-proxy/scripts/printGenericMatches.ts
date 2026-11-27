import { genericFoodCount, matchGenericFood } from '../src/mealPhoto/genericMatch'

// [name, genericName, preparation]
export const QUERIES: ReadonlyArray<readonly [string, string | null, string | null]> = [
  ['Lemon wedge', 'Lemon, raw', null],
  ['Cherry tomatoes', 'Tomatoes, raw', null],
  ['Avocado slices', 'Avocado, raw', null],
  ['Mixed greens', 'Lettuce, raw', null],
  ['Grilled salmon', 'Fish, salmon, grilled', 'grilled'],
  ['Brown rice', 'Rice, brown, cooked', 'cooked'],
  ['White rice', 'Rice, white, cooked', 'cooked'],
  ['French fries', 'Potato, french fries, restaurant', 'fried'],
  ['Cheeseburger', 'Cheeseburger, plain, on bun', null],
  ['Spaghetti with meat sauce', 'Spaghetti with meat sauce', 'cooked'],
  ['Olive oil', 'Olive oil', null],
  ['Scrambled eggs', 'Eggs, scrambled', 'scrambled'],
  ['Grilled chicken breast', 'Chicken breast, grilled', 'grilled'],
  ['Steamed broccoli', 'Broccoli, steamed', 'steamed'],
  ['Banana', 'Banana, raw', null],
  ['Apple slices', 'Apple, raw', null],
  ['Strawberries', 'Strawberries, raw', null],
  ['Cucumber slices', 'Cucumber, raw', null],
  ['Carrot sticks', 'Carrots, raw', null],
  ['Baked potato', 'Potato, baked', 'baked'],
  ['Mashed potatoes', 'Potatoes, mashed', null],
  ['Pepperoni pizza', 'Pizza, pepperoni', null],
  ['Caesar salad', 'Caesar salad', null],
  ['Steak', 'Beef steak, grilled', 'grilled'],
  ['Bacon', 'Bacon, cooked', 'fried'],
  ['Toast', 'Bread, white, toasted', 'toasted'],
  ['Greek yogurt', 'Yogurt, Greek, plain', null],
  ['Cheddar cheese', 'Cheese, cheddar', null],
  ['Sushi roll', 'Sushi, with fish', null],
]

if (import.meta.main) {
  console.log(`bundled foods: ${genericFoodCount}`)
  for (const [name, genericName, preparation] of QUERIES) {
    const match = matchGenericFood({ name, genericName, preparation })
    const result = match == null ? 'null' : `${match.description} [${match.fdcId}] ${match.per100g.calories} kcal/100g`
    console.log(`${name} | ${genericName ?? '-'} -> ${result}`)
  }
}
