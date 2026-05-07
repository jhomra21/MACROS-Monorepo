import { describe, expect, it } from "bun:test";

import {
  assertCurrentDayKey,
  assertValidSnapshot,
  canonicalPairKey,
  closeIntervalEndDay,
  isDayVisibleFromIntervals,
  normalizeDisplayName,
} from "../convex/sharingModel";

describe("sharing model privacy rules", () => {
  it("canonicalizes profile pairs and blocks self relationships", () => {
    expect(canonicalPairKey("b", "a")).toBe("a:b");
    expect(() => canonicalPairKey("a", "a")).toThrow("Cannot share");
  });

  it("hides the current day when an interval has been closed", () => {
    expect(
      isDayVisibleFromIntervals("2026-05-06", "2026-05-06", [
        { startDay: "2026-05-01", endDay: "2026-05-05" },
      ]),
    ).toBe(false);
  });

  it("keeps prior allowed days visible while excluding disabled gaps", () => {
    const intervals = [
      { startDay: "2026-05-01", endDay: "2026-05-05" },
      { startDay: "2026-05-10" },
    ];

    expect(isDayVisibleFromIntervals("2026-05-04", "2026-05-12", intervals)).toBe(true);
    expect(isDayVisibleFromIntervals("2026-05-07", "2026-05-12", intervals)).toBe(false);
    expect(isDayVisibleFromIntervals("2026-05-12", "2026-05-12", intervals)).toBe(true);
  });

  it("closes same-day disables at the previous day for visibility", () => {
    expect(closeIntervalEndDay("2026-05-06")).toBe("2026-05-05");
  });
});

describe("sharing input validation", () => {
  it("normalizes display names", () => {
    expect(normalizeDisplayName("  Juan   R  ")).toBe("Juan R");
    expect(() => normalizeDisplayName("")).toThrow("Display name");
  });

  it("bounds snapshot payloads broadly", () => {
    expect(() =>
      assertValidSnapshot({
        day: "2026-05-06",
        timeZoneId: "America/Los_Angeles",
        calories: 1200,
        protein: 100,
        fat: 50,
        carbs: 140,
        entryCount: 3,
      }),
    ).not.toThrow();

    expect(() =>
      assertValidSnapshot({
        day: "2026-05-06",
        timeZoneId: "America/Los_Angeles",
        calories: 50_001,
        protein: 100,
        fat: 50,
        carbs: 140,
        entryCount: 3,
      }),
    ).toThrow("calories");
  });

  it("rejects invalid calendar day keys", () => {
    expect(() =>
      assertValidSnapshot({
        day: "2026-02-31",
        timeZoneId: "America/Los_Angeles",
        calories: 1200,
        protein: 100,
        fat: 50,
        carbs: 140,
        entryCount: 3,
      }),
    ).toThrow("Day must be yyyy-MM-dd.");
  });

  it("limits dashboard day keys to the server-current window", () => {
    const now = new Date("2026-05-07T12:00:00.000Z");
    expect(() => assertCurrentDayKey("2026-05-06", now)).not.toThrow();
    expect(() => assertCurrentDayKey("2026-05-07", now)).not.toThrow();
    expect(() => assertCurrentDayKey("2026-05-08", now)).not.toThrow();
    expect(() => assertCurrentDayKey("2026-05-05", now)).toThrow("Dashboard is current-day only.");
  });
});
