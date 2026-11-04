export function decideFoodSearchBudget(timestamps: number[], cooldownUntil: number, now: number) {
  const active = timestamps.filter((time) => time > now - 60000)
  const allowed = now >= cooldownUntil && active.length < 8

  return { allowed, timestamps: allowed ? [...active, now] : active }
}
