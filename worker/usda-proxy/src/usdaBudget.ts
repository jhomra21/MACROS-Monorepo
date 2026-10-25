import { DurableObject } from 'cloudflare:workers'
import { decideUsdaBudget, parseUsdaBudgetPerMinute } from './usdaBudgetLogic'

export class UsdaBudget extends DurableObject<Env> {
  async acquire(): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
    const now = Date.now()
    const limit = parseUsdaBudgetPerMinute(this.env.USDA_BUDGET_PER_MINUTE)

    return this.ctx.storage.transactionSync(() => {
      const record = this.ctx.storage.sql
        .exec<{ window_start: number; count: number }>(
          'SELECT window_start, count FROM usda_budget WHERE id = 1',
        )
        .toArray()[0]

      const decision = decideUsdaBudget(record?.window_start, record?.count, now, limit)

      this.ctx.storage.sql.exec(
        `INSERT INTO usda_budget (id, window_start, count) VALUES (1, ?, ?)
         ON CONFLICT(id) DO UPDATE SET window_start = excluded.window_start, count = excluded.count`,
        decision.windowStart,
        decision.nextCount,
      )

      return {
        allowed: decision.allowed,
        retryAfterSeconds: decision.retryAfterSeconds,
      }
    })
  }

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env)
    this.ctx.storage.sql.exec(
      'CREATE TABLE IF NOT EXISTS usda_budget (id INTEGER PRIMARY KEY, window_start INTEGER NOT NULL, count INTEGER NOT NULL)',
    )
  }
}
