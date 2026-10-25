export const USDA_BUDGET_WINDOW_MS = 60_000

export interface UsdaBudgetDecision {
  allowed: boolean
  retryAfterSeconds: number
  nextCount: number
  windowStart: number
}

export function decideUsdaBudget(
  currentWindowStart: number | undefined,
  currentCount: number | undefined,
  now: number,
  limit: number,
): UsdaBudgetDecision {
  const windowStart = Math.floor(now / USDA_BUDGET_WINDOW_MS) * USDA_BUDGET_WINDOW_MS
  const count = currentWindowStart === windowStart ? currentCount ?? 0 : 0
  const allowed = count < limit

  return {
    allowed,
    retryAfterSeconds: Math.max(1, Math.ceil((windowStart + USDA_BUDGET_WINDOW_MS - now) / 1_000)),
    nextCount: allowed ? count + 1 : count,
    windowStart,
  }
}
