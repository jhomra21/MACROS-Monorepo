import { searchTokens } from './searchText'

export function isRestaurantLikeQuery(query: string): boolean {
  const tokens = searchTokens(query, { removeApostrophes: true })
  if (tokens.length < 2 || tokens.every((token) => /^\d+$/.test(token))) {
    return false
  }

  const tokenSet = new Set(tokens)
  const menuTokenCount = tokens.filter((token) => MENU_ITEM_TOKENS.has(token)).length
  const packagedTokenCount = tokens.filter((token) => PACKAGED_FOOD_TOKENS.has(token)).length

  if (packagedTokenCount > 0 && menuTokenCount === 0) {
    return false
  }

  if (hasRestaurantPhrase(tokens)) {
    return true
  }

  if (tokens.some((token) => RESTAURANT_CHAIN_TOKENS.has(token)) && menuTokenCount > 0) {
    return true
  }

  return menuTokenCount > 0 && (packagedTokenCount === 0 || hasLikelyRestaurantQualifier(tokens, tokenSet))
}

function hasRestaurantPhrase(tokens: string[]): boolean {
  const normalized = tokens.join(' ')
  return RESTAURANT_PHRASES.some((phrase) => normalized.includes(phrase))
}

function hasLikelyRestaurantQualifier(tokens: string[], tokenSet: Set<string>): boolean {
  if (tokens.some((token) => RESTAURANT_CONTEXT_TOKENS.has(token))) {
    return true
  }

  if (tokens.length >= 3 && tokens.some((token) => MENU_MODIFIER_TOKENS.has(token))) {
    return true
  }

  return tokens.length >= 3 && [...tokenSet].some((token) => PACKAGED_FOOD_TOKENS.has(token) === false && MENU_ITEM_TOKENS.has(token) === false)
}

const RESTAURANT_PHRASES = [
  'arbys',
  'burger king',
  'chick fil a',
  'checkers',
  'chipotle',
  'dairy queen',
  'dominos',
  'dunkin',
  'el pollo loco',
  'firehouse subs',
  'in and out',
  'in out',
  'jack in the box',
  'mcdonalds',
  'panera',
  'popeyes',
  'shake shack',
  'sonic',
  'starbucks',
  'subway',
  'taco bell',
  'wendys',
  'whataburger',
  'five guys',
  'raising canes',
  'olive garden',
  'panda express',
  'little caesars',
  'jersey mikes',
  'jimmy johns',
  'white castle',
  'wingstop',
]

const RESTAURANT_CHAIN_TOKENS = [
  'arbys',
  'canes',
  'checkers',
  'chickfila',
  'chipotle',
  'dominos',
  'dunkin',
  'mcdonalds',
  'popeyes',
  'starbucks',
  'subway',
  'wendys',
  'whataburger',
  'wingstop',
].reduce((set, token) => set.add(token), new Set<string>())

const RESTAURANT_CONTEXT_TOKENS = [
  'restaurant',
  'cafe',
  'diner',
  'grill',
  'drive',
  'thru',
  'takeout',
  'combo',
  'meal',
  'kids',
  'piece',
  'pieces',
  'pc',
  'pcs',
  'order',
].reduce((set, token) => set.add(token), new Set<string>())

const MENU_MODIFIER_TOKENS = [
  'double',
  'triple',
  'jr',
  'junior',
  'deluxe',
  'supreme',
  'classic',
  'spicy',
  'crispy',
  'grilled',
  'large',
  'small',
  'medium',
].reduce((set, token) => set.add(token), new Set<string>())

const MENU_ITEM_TOKENS = [
  'burger',
  'cheeseburger',
  'sandwich',
  'nugget',
  'nuggets',
  'fries',
  'fry',
  'taco',
  'burrito',
  'quesadilla',
  'latte',
  'coffee',
  'chicken',
  'pizza',
  'wings',
  'wing',
  'bowl',
  'salad',
  'wrap',
  'sub',
  'hoagie',
  'tender',
  'tenders',
  'alfredo',
  'pasta',
  'steak',
  'ribs',
  'sushi',
  'ramen',
  'pho',
  'donut',
  'donuts',
  'muffin',
  'bagel',
  'smoothie',
  'shake',
  'blizzard',
  'sundae',
  'mcflurry',
  'whopper',
  'bigmac',
].reduce((set, token) => set.add(token), new Set<string>())

const PACKAGED_FOOD_TOKENS = [
  'bar',
  'bars',
  'cereal',
  'yogurt',
  'chips',
  'chip',
  'milk',
  'powder',
  'protein',
  'granola',
  'cracker',
  'crackers',
  'cookie',
  'cookies',
  'candy',
  'gum',
  'soda',
  'water',
  'juice',
  'can',
  'bottle',
  'pack',
  'bag',
  'box',
  'frozen',
  'canned',
  'bread',
  'cheese',
  'butter',
  'oats',
  'oatmeal',
  'rice',
  'beans',
  'pasta',
  'sauce',
  'dressing',
  'cheerios',
  'kind',
  'chobani',
  'quest',
  'nature',
  'valley',
  'clif',
].reduce((set, token) => set.add(token), new Set<string>())
