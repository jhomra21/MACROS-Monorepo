/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

const modules = import.meta.glob("../**/*.ts");

const day = "2026-10-13";

const snapshot = {
  day,
  timeZoneId: "UTC",
  calories: 100,
  protein: 10,
  fat: 2,
  carbs: 3,
  entryCount: 1,
};

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-10-13T23:59:00Z"));
});

afterEach(() => {
  vi.useRealTimers();
});

test("daily quotas increment and reset on UTC day rollover", async () => {
  const t = convexTest(schema, modules);
  const profileKey = "Q".repeat(32);
  await t.run(async (ctx) => ctx.db.insert("profiles", {
    profileKey, displayName: "QA", secretHash: "a".repeat(64), createdAt: Date.now(), updatedAt: Date.now(),
  }));
  const owner = t.withIdentity({ subject: profileKey });

  await owner.mutation(api.sharing.createInvite, { tokenHash: "1".repeat(64) });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "2".repeat(64) });
  const quota = await t.run(async (ctx) => ctx.db.query("profileQuotas").first());
  expect(quota?.invitesCreated).toBe(2);
  expect(quota?.dayKey).toBe(new Date().toISOString().slice(0, 10));
});

test("daily quotas reject the first mutation beyond the configured cap", async () => {
  const t = convexTest(schema, modules);
  const profileKey = "R".repeat(32);
  await t.run(async (ctx) => ctx.db.insert("profiles", {
    profileKey, displayName: "QA", secretHash: "b".repeat(64), createdAt: Date.now(), updatedAt: Date.now(),
  }));
  const owner = t.withIdentity({ subject: profileKey });

  for (let index = 0; index < 20; index += 1) {
    await owner.mutation(api.sharing.createInvite, { tokenHash: String(index).padStart(64, "0") });
  }

  await expect(
    owner.mutation(api.sharing.createInvite, { tokenHash: "f".repeat(64) }),
  ).rejects.toThrow("QUOTA_EXCEEDED");
});

test("daily quota counters reset at UTC midnight", async () => {
  const t = convexTest(schema, modules);
  const profileKey = "S".repeat(32);
  await t.run(async (ctx) => ctx.db.insert("profiles", {
    profileKey, displayName: "QA", secretHash: "c".repeat(64), createdAt: Date.now(), updatedAt: Date.now(),
  }));
  const owner = t.withIdentity({ subject: profileKey });

  await owner.mutation(api.sharing.createInvite, { tokenHash: "a".repeat(64) });
  vi.setSystemTime(new Date("2026-10-14T00:01:00Z"));
  await owner.mutation(api.sharing.createInvite, { tokenHash: "b".repeat(64) });

  const quotas = await t.run(async (ctx) => ctx.db.query("profileQuotas").collect());
  expect(quotas.map(({ dayKey, invitesCreated }) => ({ dayKey, invitesCreated })).sort((a, b) => a.dayKey.localeCompare(b.dayKey))).toEqual([
    { dayKey: "2026-10-13", invitesCreated: 1 },
    { dayKey: "2026-10-14", invitesCreated: 1 },
  ]);
});

test("daily snapshot and display-name caps are enforced", async () => {
  const t = convexTest(schema, modules);
  const profileKey = "T".repeat(32);
  await t.run(async (ctx) => ctx.db.insert("profiles", {
    profileKey, displayName: "QA", secretHash: "d".repeat(64), createdAt: Date.now(), updatedAt: Date.now(),
  }));
  const owner = t.withIdentity({ subject: profileKey });

  for (let index = 0; index < 20; index += 1) {
    await owner.mutation(api.sharing.updateDisplayName, { displayName: `QA ${index}` });
  }

  await expect(
    owner.mutation(api.sharing.updateDisplayName, { displayName: "QA over quota" }),
  ).rejects.toThrow("QUOTA_EXCEEDED");

  for (let index = 0; index < 200; index += 1) {
    await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);
  }

  await expect(
    owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot),
  ).rejects.toThrow("QUOTA_EXCEEDED");

  const quota = await t.run(async (ctx) => ctx.db.query("profileQuotas").first());
  expect(quota?.displayNameUpdates).toBe(20);
  expect(quota?.snapshotUpserts).toBe(200);
});
