export interface SearchTextOptions {
  removeApostrophes?: boolean
}

export function normalizedSearchText(value: string, options: SearchTextOptions = {}): string {
  const withoutDiacritics = value
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')

  return (options.removeApostrophes === true
    ? withoutDiacritics.replace(/[’']/g, '')
    : withoutDiacritics)
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function searchTokens(query: string, options: SearchTextOptions = {}): string[] {
  return [...new Set(normalizedSearchText(query, options).split(' ').filter((token) => token.length > 1))]
}

export function matchesSearchTokens(
  values: Array<string | undefined>,
  tokens: string[],
  options: SearchTextOptions = {},
): boolean {
  if (tokens.length === 0) {
    return true
  }

  const searchableText = normalizedSearchText(values.filter((value): value is string => value != null).join(' '), options)
  return searchableText.length > 0 && tokens.every((token) => searchableText.includes(token))
}
