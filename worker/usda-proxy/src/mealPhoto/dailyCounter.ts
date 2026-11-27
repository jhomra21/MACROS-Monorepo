import { DurableObject } from 'cloudflare:workers'

const DAILY_LIMIT = 100

export class MealPhotoDaily extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env)
    this.ctx.storage.sql.exec(
      'CREATE TABLE IF NOT EXISTS meal_photo_daily (id TEXT PRIMARY KEY, day TEXT NOT NULL, count INTEGER NOT NULL)',
    )
  }

  canScan(installID: string, utcDay: string): boolean {
    return this.ctx.storage.transactionSync(() => {
      const result = this.ctx.storage.sql.exec<{ day: string; count: number }>(
        'SELECT day, count FROM meal_photo_daily WHERE id = ?',
        installID,
      ).toArray()[0]
      return result == null || result.day !== utcDay || result.count < DAILY_LIMIT
    })
  }

  recordSuccess(installID: string, utcDay: string): void {
    this.ctx.storage.transactionSync(() => {
      this.ctx.storage.sql.exec(
        `INSERT INTO meal_photo_daily (id, day, count) VALUES (?, ?, 1)
         ON CONFLICT(id) DO UPDATE SET
           day = excluded.day,
           count = CASE WHEN meal_photo_daily.day = excluded.day THEN meal_photo_daily.count + 1 ELSE 1 END`,
        installID,
        utcDay,
      )
    })
  }
}
