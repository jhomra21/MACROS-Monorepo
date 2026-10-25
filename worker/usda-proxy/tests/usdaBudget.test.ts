import { describe, expect, it } from 'bun:test'
import { parseUsdaBudgetPerMinute } from '../src/usdaBudgetLogic'

describe('USDA budget configuration', () => {
  it.each(['abc', '0', '', undefined])('uses the default budget for invalid limit %s', (value) => {
    expect(parseUsdaBudgetPerMinute(value)).toBe(14)
  })
})
