const connectors = new Set(['a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'with'])

export function foodDisplayText(value: string): string {
  return displayCase(value.trim().replace(/\s+/g, ' '), false)
}

export function foodDisplayBrand(value: string | undefined): string | undefined {
  const brand = value?.trim().replace(/\s+/g, ' ')
    .replace(/(?:,\s*|\s+)(?:inc\.?|llc|corp\.?|corporation|co\.?|company|limited|ltd\.?)$/i, '')
    .trim()

  return brand ? displayCase(brand, true) : undefined
}

function displayCase(value: string, isBrand: boolean): string {
  if (/\p{Ll}/u.test(value)) return value

  return value.split(' ').map((token, index) => {
    if (/\d/.test(token)) return token

    // Explicit country initialism and ampersand-separated initials only:
    // length alone would incorrectly preserve ordinary words such as THE or COW.
    if (isBrand && (token === 'USA' || /^[A-Z]&[A-Z]$/.test(token))) return token
    const lower = token.toLowerCase()

    if (index > 0 && connectors.has(lower)) return lower

    return lower.replace(/\p{L}[\p{L}'’]*/gu, (word) =>
      word.charAt(0).toUpperCase() + word.slice(1))
  }).join(' ')
}
