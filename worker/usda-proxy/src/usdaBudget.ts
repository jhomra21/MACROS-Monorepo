import { DurableObject } from 'cloudflare:workers'
import { decideUsdaBudget, parseUsdaBudgetPerMinute } from './usdaBudgetLogic'
import { decideFoodSearchBudget } from './foodSearchBudgetLogic'

export class UsdaBudget extends DurableObject<Env> {
  // V2 OFF uses a separate object name and table; the v1 acquire RPC is unchanged.
  async acquireFoodSearch(): Promise<{ allowed: boolean }> {
    return this.ctx.storage.transactionSync(() => {
      this.initializeFoodSearchBudget()

      const record = this.ctx.storage.sql
        .exec<{ timestamps: string; cooldown_until: number }>('SELECT timestamps, cooldown_until FROM food_search_budget WHERE id = 1')
        .toArray()[0]

      const timestamps: number[] = record == null ? [] : JSON.parse(record.timestamps)
      const decision = decideFoodSearchBudget(timestamps, record?.cooldown_until ?? 0, Date.now())
      this.ctx.storage.sql.exec(
        `INSERT INTO food_search_budget (id, timestamps, cooldown_until) VALUES (1, ?, 0)
         ON CONFLICT(id) DO UPDATE SET timestamps = excluded.timestamps`,
        JSON.stringify(decision.timestamps),
      )

      return { allowed: decision.allowed }
    })
  }

  async cooldownFoodSearch(milliseconds: number): Promise<void> {
    if (!Number.isFinite(milliseconds) || milliseconds <= 0) return
    this.initializeFoodSearchBudget()
    this.ctx.storage.sql.exec(
      `INSERT INTO food_search_budget (id, timestamps, cooldown_until) VALUES (1, '[]', ?)
       ON CONFLICT(id) DO UPDATE SET cooldown_until = MAX(cooldown_until, excluded.cooldown_until)`,
      Date.now() + milliseconds,
    )
  }

  private initializeFoodSearchBudget() {
    this.ctx.storage.sql.exec(
      'CREATE TABLE IF NOT EXISTS food_search_budget (id INTEGER PRIMARY KEY, timestamps TEXT NOT NULL, cooldown_until INTEGER NOT NULL)',
    )
  }

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
