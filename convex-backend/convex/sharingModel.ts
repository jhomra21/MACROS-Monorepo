export const MACROS_SCOPE = { macros: true } as const;

const DAY_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const SHA256_HEX_PATTERN = /^[a-f0-9]{64}$/;
const MIN_VISIBLE_DISPLAY_NAME_LENGTH = 1;
const MAX_DISPLAY_NAME_LENGTH = 40;

export interface ShareGrantInterval {
  startDay: string;
  endDay?: string;
}

export interface SnapshotInput {
  day: string;
  timeZoneId: string;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  entryCount: number;
}

export function normalizeDisplayName(name: string): string {
  const normalized = name.trim().replace(/\s+/g, " ");
  if (
    normalized.length < MIN_VISIBLE_DISPLAY_NAME_LENGTH ||
    normalized.length > MAX_DISPLAY_NAME_LENGTH ||
    /[\p{Cc}\p{Cf}]/u.test(normalized)
  ) {
    throw new Error("Display name must be 1–40 visible characters.");
  }
  return normalized;
}

export function assertValidSnapshot(input: SnapshotInput): void {
  assertDayKey(input.day);
  assertTimeZoneId(input.timeZoneId);
  assertNumberInRange(input.calories, 0, 50_000, "calories");
  assertNumberInRange(input.protein, 0, 10_000, "protein");
  assertNumberInRange(input.fat, 0, 10_000, "fat");
  assertNumberInRange(input.carbs, 0, 10_000, "carbs");
  assertNumberInRange(input.entryCount, 0, 1_000, "entryCount");
}

export function assertDayKey(day: string): void {
  const validCalendarDay = parseDayKey(day) === day;
  if (DAY_KEY_PATTERN.test(day) === false || validCalendarDay === false) {
    throw new Error("Day must be yyyy-MM-dd.");
  }
}

export function assertCurrentDayKey(day: string, now: Date = new Date()): void {
  assertDayKey(day);
  const currentDay = now.toISOString().slice(0, 10);
  const previousDay = offsetDayKey(currentDay, -1);
  const nextDay = offsetDayKey(currentDay, 1);
  if (day !== previousDay && day !== currentDay && day !== nextDay) {
    throw new Error("Dashboard is current-day only.");
  }
}

export function assertTokenHash(tokenHash: string): void {
  if (SHA256_HEX_PATTERN.test(tokenHash) === false) {
    throw new Error("Invite is unavailable.");
  }
}

export function canonicalPairKey(profileKeyA: string, profileKeyB: string): string {
  if (profileKeyA === profileKeyB) {
    throw new Error("Cannot share with the same profile.");
  }
  return [profileKeyA, profileKeyB].sort().join(":");
}

export function isDayVisibleFromIntervals(
  day: string,
  ownerToday: string,
  intervals: ShareGrantInterval[],
): boolean {
  assertDayKey(day);
  assertDayKey(ownerToday);

  // Privacy rule: disabling sharing mid-day hides the current day until a new active
  // interval is opened. Future history should retain a day only when sharing stayed
  // enabled through the owner-local day boundary.
  return intervals.some((interval) => {
    if (day < interval.startDay) {
      return false;
    }
    if (interval.endDay != null && day > interval.endDay) {
      return false;
    }
    if (day === ownerToday) {
      return interval.endDay == null;
    }
    return true;
  });
}

export function closeIntervalEndDay(disableDay: string): string {
  assertDayKey(disableDay);
  return offsetDayKey(disableDay, -1);
}

function parseDayKey(day: string): string | null {
  const match = DAY_KEY_PATTERN.exec(day);
  if (match == null) {
    return null;
  }
  const [year, month, date] = day.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, date)).toISOString().slice(0, 10);
}

function offsetDayKey(day: string, offset: number): string {
  const [year, month, date] = day.split("-").map(Number);
  const value = new Date(Date.UTC(year, month - 1, date));
  value.setUTCDate(value.getUTCDate() + offset);
  return value.toISOString().slice(0, 10);
}

function assertTimeZoneId(timeZoneId: string): void {
  if (timeZoneId.length < 1 || timeZoneId.length > 128) {
    throw new Error("timeZoneId is invalid.");
  }
  try {
    Intl.DateTimeFormat("en-US", { timeZone: timeZoneId }).format(new Date());
  } catch {
    throw new Error("timeZoneId is invalid.");
  }
}

function assertNumberInRange(value: number, min: number, max: number, name: string): void {
  if (Number.isFinite(value) === false || value < min || value > max) {
    throw new Error(`${name} is out of range.`);
  }
}
