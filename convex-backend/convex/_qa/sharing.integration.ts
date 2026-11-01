/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import { AppleVerifier } from "../_lib/appleVerifier.node";

const modules = import.meta.glob("../**/*.ts");

// Only the cryptographic boundary is mocked. Auth, validators, entitlement writes,
// notification ordering, HTTP routing, and sharing rules run as registered functions.
beforeEach(() => {
  vi.spyOn(AppleVerifier.prototype, "transaction").mockImplementation(async value => JSON.parse(value));
  vi.spyOn(AppleVerifier.prototype, "renewal").mockImplementation(async value => JSON.parse(value));
  vi.spyOn(AppleVerifier.prototype, "notification").mockImplementation(async value => JSON.parse(value));
});

afterEach(() => vi.restoreAllMocks());

const day = "2026-10-13";

const snapshot = { day, timeZoneId: "UTC", calories: 100, protein: 10, fat: 2, carbs: 3, entryCount: 1 };

beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-10-13T00:00:00Z")); });

afterEach(() => { vi.useRealTimers(); vi.unstubAllEnvs(); });

async function fixture() {
  const t = convexTest(schema, modules);

  const ids = await t.run(async (ctx) => {
    const result = [];

    for (const key of ["owner", "viewer", "stranger"]) {
      result.push(await ctx.db.insert("profiles", {
        profileKey: key, displayName: key, secretHash: "fixture", createdAt: Date.now(), updatedAt: Date.now(),
      }));
    }

    return result;
  });

  const [owner, viewer, stranger] = ["owner", "viewer", "stranger"].map(subject =>
    t.withIdentity({ subject, issuer: "https://qa.invalid" }));

  return { t, ids, owner, viewer, stranger };
}

test("registered authentication and unrelated visibility", async () => {
  const { t, ids, owner, stranger } = await fixture();
  await expect(t.mutation(api.sharing.createInvite, { tokenHash: "a".repeat(64) })).rejects.toThrow("Authentication");
  await expect(t.mutation(api.sharing.upsertMyDailySnapshot, snapshot)).rejects.toThrow("Authentication");
  await expect(t.query(api.sharing.sharingDashboard, { day, ownerToday: day })).rejects.toThrow("Authentication");
  await expect(t.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).rejects.toThrow(
    "Authentication",
  );
  await expect(t.mutation(api.sharing.deleteMySharingProfile, {})).rejects.toThrow("Authentication");
  await expect(t.mutation(api.sharing.removePerson, { otherProfileId: ids[0], ownerDay: day })).rejects.toThrow("Authentication");
  await expect(t.withIdentity({ subject: "absent" }).mutation(api.sharing.updateDisplayName, { displayName: "QA" })).rejects.toThrow("unavailable");
  await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);
  expect(await stranger.query(api.sharing.sharingDashboard, { day, ownerToday: day })).toEqual({ people: [] });
});

test("accept/replay, duplicate grants, snapshots, disabling, removal and deletion", async () => {
  const { t, ids, owner, viewer, stranger } = await fixture();
  const hash = "b".repeat(64);
  await owner.mutation(api.sharing.createInvite, { tokenHash: hash });
  await expect(owner.mutation(api.sharing.acceptInvite, { tokenHash: hash, ownerDay: day })).rejects.toThrow("unavailable");
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: hash, ownerDay: day });
  await expect(stranger.mutation(api.sharing.acceptInvite, { tokenHash: hash, ownerDay: day })).rejects.toThrow("unavailable");

  for (let i = 0; i < 2; i++) await owner.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[1], enabled: true, ownerDay: day });
  const first = await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);
  expect(await owner.mutation(api.sharing.upsertMyDailySnapshot, { ...snapshot, calories: 200 })).toEqual(first);
  await viewer.mutation(api.sharing.upsertMyDailySnapshot, { ...snapshot, calories: 300 });
  expect(await t.run(async ctx => (await ctx.db.query("shareGrantIntervals").collect()).length)).toBe(1);
  expect(await t.run(async ctx => (await ctx.db.query("dailySnapshots").collect()).length)).toBe(2);
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0].snapshot?.calories).toBe(200);
  expect((await owner.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0].snapshot).toBeNull();
  await expect(stranger.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[0], enabled: true, ownerDay: day })).rejects.toThrow("unavailable");
  await owner.mutation(api.sharing.stopSharingMyData, { ownerDay: day });
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0].snapshot).toBeNull();
  await owner.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[1], enabled: true, ownerDay: day });
  await viewer.mutation(api.sharing.removePerson, { otherProfileId: ids[0], ownerDay: day });
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people).toEqual([]);
  await owner.mutation(api.sharing.createInvite, { tokenHash: "c".repeat(64) });
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "c".repeat(64), ownerDay: day });
  await owner.mutation(api.sharing.deleteMySharingProfile, {});
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people).toEqual([]);
  await expect(owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot)).rejects.toThrow("unavailable");
  expect(await t.run(async ctx => ({
    invites: (await ctx.db.query("shareInvites").collect()).length,
    grants: (await ctx.db.query("shareGrantIntervals").collect()).length,
    relationships: (await ctx.db.query("shareRelationships").collect()).length,
    snapshots: (await ctx.db.query("dailySnapshots").collect()).length,
  }))).toEqual({ invites: 0, grants: 0, relationships: 0, snapshots: 1 });
});

const food = { localEntryId: "food-1", sortIndex: 0, name: "Oats", quantityText: "1 bowl", calories: 100, protein: 10, carbs: 3, fat: 2 };

const purchase = (id = "transaction-1", extra = {}) => JSON.stringify({
  bundleId: "juan-test.cal-macro-tracker", environment: "Sandbox", productId: "macros.pro.monthly",
  transactionId: id, originalTransactionId: id, expiresDate: Date.now() + 60_000, signedDate: Date.now(), ...extra,
});

async function connected() {
  const f = await fixture();
  await f.owner.mutation(api.sharing.createInvite, { tokenHash: "9".repeat(64) });
  await f.viewer.mutation(api.sharing.acceptInvite, { tokenHash: "9".repeat(64), ownerDay: day });

  return f;
}

test("build 23 exact wire shapes remain frozen and foods default off", async () => {
  const { owner, viewer, ids } = await fixture();
  const invite = await owner.mutation(api.sharing.createInvite, { tokenHash: "8".repeat(64) });
  expect(Object.keys(invite).sort()).toEqual(["expiresAt", "inviteId"]);
  const accepted = await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "8".repeat(64), ownerDay: day });
  expect(Object.keys(accepted)).toEqual(["relationshipId"]);

  for (const value of Object.values(accepted)) expect(value).toEqual(expect.any(String));
  const result = await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);
  expect(Object.keys(result)).toEqual(["snapshotId"]);
  const person = (await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0];
  expect(Object.keys(person).sort()).toEqual([
    "connectionPaused", "displayName", "foodsShared", "incomingActive", "outgoingActive",
    "outgoingScope", "profileId", "relationshipId", "scope", "snapshot",
  ]);
  expect(person.scope).toEqual({ macros: true });
  expect(person.foodsShared).toBe(false);
  expect(Object.keys(person.snapshot!).sort()).toEqual(Object.keys({ ...snapshot, updatedAt: 0 }).sort());
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const personDay = await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day });
  expect(Object.keys(personDay.snapshot!).sort()).toEqual(Object.keys({ ...snapshot, updatedAt: 0 }).sort());
  expect(personDay.foods).toEqual([]);
});

test("daily goals round-trip to dashboard and personDay, and build 23 upserts preserve them", async () => {
  const { t, owner, viewer, ids } = await connected();
  const goals = { calorieGoal: 2_100, proteinGoal: 145, carbsGoal: 230, fatGoal: 65 };
  await owner.mutation(api.sharing.syncMyDay, { snapshot: { ...snapshot, ...goals } });

  const dashboardSnapshot = (await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0].snapshot;
  expect(dashboardSnapshot).toMatchObject(goals);
  const personDaySnapshot = (await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).snapshot;
  expect(personDaySnapshot).toMatchObject(goals);

  await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);

  const stored = await t.run(ctx =>
    ctx.db.query("dailySnapshots").withIndex("by_owner_day", q => q.eq("ownerProfileId", ids[0]).eq("day", day)).unique(),
  );

  expect(stored).toMatchObject(goals);
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0].snapshot).toMatchObject(goals);
});

test("food scope patches in place, unchanged day arrays keep updatedAt, and off deletes immediately", async () => {
  const { t, owner, viewer, ids } = await connected();
  const before = await t.run(ctx => ctx.db.query("shareGrantIntervals").collect());
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const stored = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  expect(stored).toHaveLength(1);
  expect(stored[0].foods).toEqual([food]);
  vi.setSystemTime(Date.now() + 1000);
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const unchanged = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  expect(unchanged).toEqual(stored);
  expect(unchanged[0].updatedAt).toBe(stored[0].updatedAt);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([food]);
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macros", ownerDay: day });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toEqual([]);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([]);
  const after = await t.run(ctx => ctx.db.query("shareGrantIntervals").collect());
  expect(after).toHaveLength(1);
  expect(after[0]._id).toBe(before[0]._id);
  expect(after[0].startedAt).toBe(before[0].startedAt);
});

test("Pro flag gates invites and pauses both ways; flag off and either person's Pro resume", async () => {
  const { t, owner, viewer, ids } = await connected();
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const setting = await t.run(ctx => ctx.db.insert("settings", { sharingRequirePro: true }));
  await expect(owner.mutation(api.sharing.createInvite, { tokenHash: "7".repeat(64) })).rejects.toThrow("Pro");
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toEqual([]);
  const person = (await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people[0];
  expect(person.connectionPaused).toBe(true);
  expect(person.foodsShared).toBe(false);
  expect(person.snapshot).toBeNull();
  expect(await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).toEqual({
    visibility: "paused", snapshot: null, foods: [],
  });
  await viewer.action(api.entitlements.submitPurchase, { signedTransaction: purchase() });
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toHaveLength(1);
  await t.run(ctx => ctx.db.patch(setting, { sharingRequirePro: false }));
  await owner.mutation(api.sharing.createInvite, { tokenHash: "7".repeat(64) });
});

test("personDay returns notShared when inbound grant is absent or ends", async () => {
  const { owner, viewer, ids } = await connected();
  const personDay = () => viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day });
  await owner.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[1], enabled: false, ownerDay: day });
  expect(await personDay()).toEqual({ visibility: "notShared", snapshot: null, foods: [] });
  await owner.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[1], enabled: true, ownerDay: day });
  expect((await personDay()).visibility).toBe("shared");
  await owner.mutation(api.sharing.setOutgoingSharingForPerson, { toProfileId: ids[1], enabled: false, ownerDay: day });
  expect(await personDay()).toEqual({ visibility: "notShared", snapshot: null, foods: [] });
});

test("personDay rejects past days, removed relationships, deleted people and strangers", async () => {
  const { t, owner, viewer, stranger, ids } = await connected();
  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day: "2026-10-12", ownerToday: day })).rejects.toThrow("current-day");
  await expect(stranger.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).rejects.toThrow("unavailable");
  await viewer.mutation(api.sharing.removePerson, { otherProfileId: ids[0], ownerDay: day });
  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).rejects.toThrow("unavailable");
  await t.run(ctx => ctx.db.patch(ids[0], { deletedAt: Date.now() }));
  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).rejects.toThrow("unavailable");
  await expect(owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [] })).rejects.toThrow("unavailable");
});

test("personDay rejects a deleted related profile", async () => {
  const { t, viewer, ids } = await connected();
  await t.run(ctx => ctx.db.patch(ids[0], { deletedAt: Date.now() }));

  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).rejects.toThrow(
    "unavailable",
  );
});

test("100 food cap, bounded fields, unique local IDs and user/day isolation", async () => {
  const { t, owner, viewer, stranger, ids } = await connected();
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  const foods = Array.from({ length: 100 }, (_, i) => ({ ...food, localEntryId: `f-${i}`, sortIndex: 99 - i }));
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods });
  await expect(owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [...foods, food] })).rejects.toThrow("100");

  for (const bad of [{ name: "x".repeat(81) }, { quantityText: "x".repeat(41) }, { calories: -1 }, { localEntryId: "" }]) {
    await expect(owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [{ ...food, ...bad }] })).rejects.toThrow();
  }

  await expect(owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food, food] })).rejects.toThrow();
  await stranger.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const stored = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  expect(stored).toHaveLength(1);
  expect(stored[0].foods).toHaveLength(100);
  const detail = await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day });
  expect(detail.foods.map(f => f.sortIndex)).toEqual(Array.from({ length: 100 }, (_, i) => i));
  vi.setSystemTime(new Date("2026-10-14T12:00:00Z"));
  await owner.mutation(api.sharing.syncMyDay, { snapshot: { ...snapshot, day: "2026-10-14" }, foods: [food] });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toHaveLength(1);
  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: "2026-10-14" })).rejects.toThrow();
});

test("batched deletion drains every owned table beyond 100 rows", async () => {
  const { t, owner, viewer, ids } = await connected();
  await t.run(async ctx => {
    for (let i = 0; i < 205; i++) {
      await ctx.db.insert("dailySnapshots", { ...snapshot, ownerProfileId: ids[0], day: `old-${i}`, updatedAt: 0 });
      await ctx.db.insert("sharedFoodDays", { foods: [food], ownerProfileId: ids[0], day: `old-${i}`, updatedAt: 0 });
      await ctx.db.insert("purchaseLinks", { profileId: ids[0], originalTransactionId: `t-${i}` });
      await ctx.db.insert("profileQuotas", { profileId: ids[0], dayKey: `old-${i}`, invitesCreated: 0, snapshotUpserts: 0, displayNameUpdates: 0 });
    }
  });
  expect(await owner.mutation(api.sharing.deleteMySharingProfile, {})).toEqual({ ok: true });
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people).toEqual([]);
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect(await t.run(async ctx => Promise.all([
    ctx.db.query("dailySnapshots").collect(), ctx.db.query("sharedFoodDays").collect(),
    ctx.db.query("purchaseLinks").collect(), ctx.db.query("profileQuotas").collect(),
    ctx.db.query("shareGrantIntervals").collect(), ctx.db.query("shareRelationships").collect(),
    ctx.db.query("shareInvites").collect(),
  ]))).toEqual([[], [], [], [], [], [], []]);
});

test("purchase cap is five distinct profiles and retries do not consume slots", async () => {
  const { t, owner } = await fixture();
  const signedTransaction = purchase("capped");
  await owner.action(api.entitlements.submitPurchase, { signedTransaction });
  await owner.action(api.entitlements.submitPurchase, { signedTransaction });

  for (let i = 1; i <= 5; i++) {
    const key = `cap-${i}`;
    await t.run(ctx => ctx.db.insert("profiles", { profileKey: key, displayName: key, secretHash: "fixture", createdAt: 0, updatedAt: 0 }));
    const call = t.withIdentity({ subject: key }).action(api.entitlements.submitPurchase, { signedTransaction });

    if (i === 5) await expect(call).rejects.toThrow("5");
    else await call;
  }

  expect(await t.run(ctx => ctx.db.query("purchaseLinks").collect())).toHaveLength(5);
});

test("grace counts as Pro; expired, revoked, unknown products and mismatched renewal do not grant Pro", async () => {
  const { t, owner } = await fixture();
  await t.run(ctx => ctx.db.insert("settings", { sharingRequirePro: true }));
  const expired = purchase("grace", { expiresDate: Date.now() - 1 });
  await owner.action(api.entitlements.submitPurchase, { signedTransaction: expired });
  await expect(owner.mutation(api.sharing.createInvite, { tokenHash: "6".repeat(64) })).rejects.toThrow("Pro");
  const signedRenewalInfo = JSON.stringify({ originalTransactionId: "grace", environment: "Sandbox", productId: "macros.pro.monthly", gracePeriodExpiresDate: Date.now() + 60_000, signedDate: Date.now() + 1 });
  await owner.action(api.entitlements.submitPurchase, { signedTransaction: expired, signedRenewalInfo });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "6".repeat(64) });
  await expect(owner.action(api.entitlements.submitPurchase, { signedTransaction: purchase("other"), signedRenewalInfo })).rejects.toThrow();
  await expect(owner.action(api.entitlements.submitPurchase, { signedTransaction: purchase("legacy", { productId: "fullunlock001" }) })).rejects.toThrow();
});

test("notification HTTP ordering, grace, expiry, refund, renewal, and unknown transaction 200", async () => {
  const { t, owner } = await fixture();
  await owner.action(api.entitlements.submitPurchase, { signedTransaction: purchase("notify") });
  const start = Date.now();

  const send = async (type: string, signedDate: number, originalTransactionId = "notify", subtype?: string) => t.fetch("/appstore/notifications", {
    method: "POST", body: JSON.stringify({ signedPayload: JSON.stringify({
      notificationType: type, subtype, signedDate, data: { environment: "Sandbox",
        signedTransactionInfo: purchase(originalTransactionId, { expiresDate: type === "EXPIRED" ? start : start + 5000, signedDate }),
        signedRenewalInfo: JSON.stringify({ environment: "Sandbox", originalTransactionId, productId: "macros.pro.monthly",
          gracePeriodExpiresDate: type === "EXPIRED" ? undefined : start + 100_000, signedDate }),
      },
    }) }),
  });

  expect((await send("REFUND", start + 10)).status).toBe(200);
  expect((await send("DID_RENEW", start + 5)).status).toBe(200);
  let row = (await t.run(ctx => ctx.db.query("appleTransactions").collect()))[0];
  expect(row.revokedAt).toBeDefined();
  expect(row.transactionSignedDate).toBe(start + 10);
  expect((await send("DID_RENEW", start + 20)).status).toBe(200);
  row = (await t.run(ctx => ctx.db.query("appleTransactions").collect()))[0];
  expect(row.revokedAt).toBeUndefined();
  expect((await send("DID_FAIL_TO_RENEW", start + 30, "notify", "GRACE_PERIOD")).status).toBe(200);
  expect((await t.run(ctx => ctx.db.query("appleRenewals").collect()))[0].gracePeriodExpiresAt).toBe(start + 100_000);
  expect((await send("EXPIRED", start + 40)).status).toBe(200);
  row = (await t.run(ctx => ctx.db.query("appleTransactions").collect()))[0];
  expect(row.expiresAt).toBeLessThanOrEqual(start + 40);
  expect((await send("SUBSCRIBED", start + 50, "unknown")).status).toBe(200);
  expect((await t.fetch("/appstore/notifications", { method: "POST", body: JSON.stringify({ signedPayload: "garbage" }) })).status).toBe(400);
});

test("weekly bounded sweeper deletes all food days before today, retaining today and future days", async () => {
  const { t, ids } = await fixture();
  await t.run(async ctx => {
    for (let i = 0; i < 205; i++) {
      const oldDay = new Date(Date.UTC(2025, 0, i + 1)).toISOString().slice(0, 10);
      await ctx.db.insert("sharedFoodDays", { foods: [food], day: oldDay, ownerProfileId: ids[0], updatedAt: 0 });
    }

    for (const value of ["2026-10-12", day, "2026-10-14"]) {
      await ctx.db.insert("sharedFoodDays", { foods: [food], day: value, ownerProfileId: ids[0], updatedAt: 0 });
    }
  });
  await t.mutation(internal.foodCleanup.sweep, {});
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toHaveLength(108);
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect((await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).map(row => row.day)).toEqual([day, "2026-10-14"]);
});

test("stale purchases cannot revive a refund for existing or newly attached profiles", async () => {
  const { t, owner, viewer } = await fixture();
  const signedTransaction = purchase("refunded");
  await owner.action(api.entitlements.submitPurchase, { signedTransaction });
  await t.mutation(internal.entitlementRecords.applyNotification, {
    transaction: {
      transactionId: "refunded", productId: "macros.pro.monthly", originalTransactionId: "refunded", environment: "Sandbox",
      expiresAt: Date.now() + 60_000, revokedAt: Date.now() + 10, transactionSignedDate: Date.now() + 10,
    },
  });
  await expect(owner.action(api.entitlements.submitPurchase, { signedTransaction })).rejects.toThrow("revoked");
  await expect(viewer.action(api.entitlements.submitPurchase, { signedTransaction })).rejects.toThrow("revoked");
  const rows = await t.run(ctx => ctx.db.query("appleTransactions").collect());
  expect(rows).toHaveLength(1);

  for (const row of rows) expect(row.revokedAt).toBe(Date.now() + 10);
  expect(rows[0].transactionSignedDate).toBe(Date.now() + 10);
  expect(await t.run(ctx => ctx.db.query("purchaseLinks").collect())).toHaveLength(1);
});

test("a new verified renewal updates every profile attached to that purchase", async () => {
  const { t, owner, viewer } = await fixture();
  const signedTransaction = purchase("renewed");
  await owner.action(api.entitlements.submitPurchase, { signedTransaction });
  await viewer.action(api.entitlements.submitPurchase, { signedTransaction });
  const expiresDate = Date.now() + 120_000;
  await owner.action(api.entitlements.submitPurchase, {
    signedTransaction: purchase("renewed", { signedDate: Date.now() + 10, expiresDate }),
  });
  const rows = await t.run(ctx => ctx.db.query("appleTransactions").collect());
  expect(rows.map(row => row.expiresAt)).toEqual([expiresDate]);
  expect(await t.run(ctx => ctx.db.query("proStatus").collect())).toEqual([
    expect.objectContaining({ active: true, activeUntil: expiresDate }),
    expect.objectContaining({ active: true, activeUntil: expiresDate }),
  ]);
});

test("a newer renewal JWS cannot clear a refund using an older transaction", async () => {
  const { t, owner } = await fixture();
  const signedTransaction = purchase("refund-renewal");
  await owner.action(api.entitlements.submitPurchase, { signedTransaction });
  await t.mutation(internal.entitlementRecords.applyNotification, {
    transaction: {
      transactionId: "refund-renewal", productId: "macros.pro.monthly", originalTransactionId: "refund-renewal", environment: "Sandbox",
      revokedAt: Date.now() + 10, transactionSignedDate: Date.now() + 10,
    },
  });
  await expect(owner.action(api.entitlements.submitPurchase, {
    signedTransaction,
    signedRenewalInfo: JSON.stringify({
      productId: "macros.pro.monthly", originalTransactionId: "refund-renewal", environment: "Sandbox",
      gracePeriodExpiresDate: Date.now() + 60_000, signedDate: Date.now() + 20,
    }),
  })).rejects.toThrow("revoked");
  const row = (await t.run(ctx => ctx.db.query("appleTransactions").collect()))[0];
  expect(row.revokedAt).toBe(Date.now() + 10);
});

test("lifetime grants Pro without expiry; revoked purchases never do", async () => {
  const { t, owner, viewer } = await fixture();
  await t.run(ctx => ctx.db.insert("settings", { sharingRequirePro: true }));
  await expect(viewer.action(api.entitlements.submitPurchase, {
    signedTransaction: purchase("revoked", { revocationDate: Date.now() - 1 }),
  })).rejects.toThrow("revoked");
  await expect(viewer.mutation(api.sharing.createInvite, { tokenHash: "4".repeat(64) })).rejects.toThrow("Pro");
  await owner.action(api.entitlements.submitPurchase, {
    signedTransaction: purchase("lifetime", { productId: "macros.pro.lifetime", expiresDate: undefined }),
  });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "4".repeat(64) });
});

test("verified non-Pro notifications are acknowledged without granting an entitlement", async () => {
  const { t } = await fixture();

  const response = await t.fetch("/appstore/notifications", {
    method: "POST", body: JSON.stringify({ signedPayload: JSON.stringify({
      notificationType: "SUBSCRIBED", signedDate: Date.now(), data: {
        environment: "Sandbox", signedTransactionInfo: purchase("legacy-notify", { productId: "fullunlock001" }),
      },
    }) }),
  });

  expect(response.status).toBe(200);
  expect(await t.run(ctx => ctx.db.query("appleTransactions").collect())).toEqual([]);
});

test("scope without ownerDay uses server today; other recipients keep foods until the last one turns off", async () => {
  const { t, owner, viewer, stranger, ids } = await connected();
  await owner.mutation(api.sharing.createInvite, { tokenHash: "5".repeat(64) });
  await stranger.mutation(api.sharing.acceptInvite, { tokenHash: "5".repeat(64), ownerDay: day });

  for (const otherProfileId of [ids[1], ids[2]]) {
    await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId, scope: "macrosAndFoods" });
  }

  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macros" });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toHaveLength(1);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([]);
  expect((await stranger.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toHaveLength(1);
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[2], scope: "off" });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toEqual([]);
});

test("food day replacement preserves document identity and removes omitted foods", async () => {
  const { t, owner, viewer, ids } = await connected();
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food, { ...food, localEntryId: "food-2" }] });
  const before = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  vi.setSystemTime(Date.now() + 1000);
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [{ ...food, calories: 200 }] });
  const after = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  expect(after).toHaveLength(1);
  expect(after[0]._id).toBe(before[0]._id);
  expect(after[0].updatedAt).toBeGreaterThan(before[0].updatedAt);
  expect(after[0].foods).toEqual([{ ...food, calories: 200 }]);
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [] });
  expect((await t.run(ctx => ctx.db.query("sharedFoodDays").collect()))[0].foods).toEqual([]);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([]);
  await expect(viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day: "2026-10-10", ownerToday: "2026-10-10" })).rejects.toThrow("current-day");
});

test("canonical food arrays ignore property and input order, keeping updatedAt unchanged", async () => {
  const { t, owner, viewer, ids } = await connected();
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  const second = { ...food, localEntryId: "food-2", sortIndex: 2 };
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [second, food] });
  const stored = await t.run(ctx => ctx.db.query("sharedFoodDays").unique());
  expect(stored).toMatchObject({ foods: [food, second], updatedAt: expect.any(Number) });
  vi.setSystemTime(Date.now() + 1000);

  const reorderedFields = {
    fat: food.fat, carbs: food.carbs, protein: food.protein, calories: food.calories,
    quantityText: food.quantityText, name: food.name, sortIndex: food.sortIndex, localEntryId: food.localEntryId,
  };

  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [reorderedFields, second] });
  const unchanged = await t.run(ctx => ctx.db.query("sharedFoodDays").unique());
  expect(unchanged?._id).toBe(stored?._id);
  expect(unchanged?.updatedAt).toBe(stored?.updatedAt);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([food, second]);
  await owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot);
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").unique())).toEqual(unchanged);
});

test("food day documents isolate two sharing owners and never embed foods in profiles, totals, or dashboard", async () => {
  const { t, owner, viewer, stranger, ids } = await connected();
  await stranger.mutation(api.sharing.createInvite, { tokenHash: "a".repeat(64) });
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "a".repeat(64), ownerDay: day });

  for (const sender of [owner, stranger]) {
    await sender.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  }

  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  const otherFood = { ...food, name: "Stranger's food", calories: 999 };
  await stranger.mutation(api.sharing.syncMyDay, { snapshot, foods: [otherFood] });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toHaveLength(2);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[0], day, ownerToday: day })).foods).toEqual([food]);
  expect((await viewer.query(api.sharing.personDay, { otherProfileId: ids[2], day, ownerToday: day })).foods).toEqual([otherFood]);
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macros", ownerDay: day });
  expect((await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).map(row => row.ownerProfileId)).toEqual([ids[2]]);
  const dashboard = await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day });

  for (const person of dashboard.people) {
    expect(person).not.toHaveProperty("foods");
    expect(person.snapshot).not.toHaveProperty("foods");
  }

  for (const profile of await t.run(ctx => ctx.db.query("profiles").collect())) expect(profile).not.toHaveProperty("foods");

  for (const totals of await t.run(ctx => ctx.db.query("dailySnapshots").collect())) expect(totals).not.toHaveProperty("foods");
  // SAFETY: deliberately sends an unsupported private field to verify the food whitelist rejects it.
  const invalidFood = { ...food, notes: "must not be stored" };
  await expect(stranger.mutation(api.sharing.syncMyDay, { snapshot, foods: [invalidFood] })).rejects.toThrow();
});

test("first sync removes old owner food days in bounded batches, preserving other users and current/future days", async () => {
  const { t, owner, ids } = await connected();
  await owner.mutation(api.sharing.setOutgoingScope, { otherProfileId: ids[1], scope: "macrosAndFoods", ownerDay: day });
  await t.run(async ctx => {
    for (let i = 0; i < 205; i++) {
      const oldDay = new Date(Date.UTC(2025, 0, i + 1)).toISOString().slice(0, 10);
      await ctx.db.insert("sharedFoodDays", { ownerProfileId: ids[0], day: oldDay, foods: [food], updatedAt: 0 });
    }

    await ctx.db.insert("sharedFoodDays", { ownerProfileId: ids[0], day: "2026-10-14", foods: [food], updatedAt: 0 });
    await ctx.db.insert("sharedFoodDays", { ownerProfileId: ids[2], day: "2026-10-12", foods: [food], updatedAt: 0 });
  });
  await owner.mutation(api.sharing.syncMyDay, { snapshot, foods: [food] });
  expect(await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).toHaveLength(108);
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  const remaining = await t.run(ctx => ctx.db.query("sharedFoodDays").collect());
  expect(remaining).toHaveLength(3);
  expect(remaining.map(row => row.day).sort()).toEqual(["2026-10-12", day, "2026-10-14"]);
  await owner.mutation(api.sharing.deleteMySharingProfile, {});
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect((await t.run(ctx => ctx.db.query("sharedFoodDays").collect())).map(row => row.ownerProfileId)).toEqual([ids[2]]);
});

test("bootstrap rejects malformed JSON, non-string fields and invalid bounds with 400", async () => {
  const { t } = await fixture();
  vi.stubEnv("MACROS_BOOTSTRAP_SECRET", "synthetic-qa-bootstrap");

  for (const body of ["{", "null", "[]", JSON.stringify({ profileKey: 7, secretHash: {}, displayName: [] }), JSON.stringify({ profileKey: "x", secretHash: "nope" })]) {
    expect((await t.fetch("/v1/bootstrap-profile", { method: "POST", headers: { "x-macros-bootstrap-secret": "synthetic-qa-bootstrap" }, body })).status).toBe(400);
  }
});

test("revocation and exact expiry reject without relationship mutation", async () => {
  const { t, owner, viewer, stranger } = await fixture();
  const old = await owner.mutation(api.sharing.createInvite, { tokenHash: "d".repeat(64) });
  await expect(stranger.mutation(api.sharing.revokePendingInvite, { inviteId: old.inviteId })).rejects.toThrow("unavailable");
  await owner.mutation(api.sharing.revokePendingInvite, { inviteId: old.inviteId });
  await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash: "d".repeat(64), ownerDay: day })).rejects.toThrow("unavailable");
  const expiring = await owner.mutation(api.sharing.createInvite, { tokenHash: "e".repeat(64) });
  vi.setSystemTime(expiring.expiresAt);
  await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash: "e".repeat(64), ownerDay: day })).rejects.toThrow("unavailable");
  expect(await t.run(async ctx => (await ctx.db.query("shareRelationships").collect()).length)).toBe(0);
});

test("snapshot bounds and UTC timezone day window use framework clock", async () => {
  const { t, owner } = await fixture();

  for (const invalid of [
    { day: "2026-02-30" }, { timeZoneId: "Not/AZone" }, { calories: -1 },
    { protein: 10001 }, { entryCount: 1001 }, { calories: Number.NaN },
  ]) await expect(owner.mutation(api.sharing.upsertMyDailySnapshot, { ...snapshot, ...invalid })).rejects.toThrow();
  expect(await t.run(async ctx => (await ctx.db.query("dailySnapshots").collect()).length)).toBe(0);

  for (const value of ["2026-10-12", day, "2026-10-14"]) {
    expect(await owner.query(api.sharing.sharingDashboard, { day: value, ownerToday: value })).toEqual({ people: [] });
  }

  for (const value of ["2026-10-11", "2026-10-15"]) {
    await expect(owner.query(api.sharing.sharingDashboard, { day: value, ownerToday: value })).rejects.toThrow("current-day");
  }

  await expect(owner.query(api.sharing.sharingDashboard, { day, ownerToday: "2026-10-12" })).rejects.toThrow("current-day");
  await owner.mutation(api.sharing.upsertMyDailySnapshot, { ...snapshot, timeZoneId: "Pacific/Kiritimati" });
});

test("renewed invites consolidate relationships and supersede pending invites", async () => {
  const { t, owner, viewer } = await fixture();
  await owner.mutation(api.sharing.createInvite, { tokenHash: "1".repeat(64) });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "2".repeat(64) });
  await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash: "1".repeat(64), ownerDay: day })).rejects.toThrow("unavailable");
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "2".repeat(64), ownerDay: day });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "3".repeat(64) });
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "3".repeat(64), ownerDay: day });
  expect(await t.run(async ctx => ({
    relationships: (await ctx.db.query("shareRelationships").collect()).length,
    grants: (await ctx.db.query("shareGrantIntervals").collect()).length,
  }))).toEqual({ relationships: 1, grants: 1 });
});

test("snapshot identity cannot be overridden through public mutation arguments", async () => {
  const { t, ids, viewer } = await fixture();
  // SAFETY: the test deliberately includes an unsupported ownerProfileId field to prove the public validator rejects it.
  const invalidSnapshot = { ...snapshot, ownerProfileId: ids[0] };
  await expect(viewer.mutation(api.sharing.upsertMyDailySnapshot, invalidSnapshot)).rejects.toThrow();
  expect(await t.run(async ctx => (await ctx.db.query("dailySnapshots").collect()).length)).toBe(0);
});

test("actual bootstrap HTTP router protects mutations and verifies credentials", async () => {
  const t = convexTest(schema, modules);
  vi.stubEnv("MACROS_BOOTSTRAP_SECRET", "synthetic-qa-bootstrap");
  const body = { profileKey: "Q".repeat(32), secretHash: "a".repeat(64), displayName: "QA Owner" };

  const send = (secret?: string, value = body) => {
    const headers = new Headers({ "content-type": "application/json" });

    if (secret != null) {
      headers.set("x-macros-bootstrap-secret", secret);
    }

    return t.fetch("/v1/bootstrap-profile", {
      method: "POST",
      headers,
      body: JSON.stringify(value),
    });
  };

  expect((await send()).status).toBe(401);
  expect((await send("wrong")).status).toBe(401);
  expect(await t.run(async ctx => (await ctx.db.query("profiles").collect()).length)).toBe(0);
  expect((await send("synthetic-qa-bootstrap")).status).toBe(200);
  expect((await send("synthetic-qa-bootstrap")).status).toBe(200);
  expect(await t.run(async ctx => (await ctx.db.query("profiles").collect()).length)).toBe(1);
  // convex-test propagates handler errors instead of providing Convex's outer HTTP 500 envelope.
  await expect(send("synthetic-qa-bootstrap", { ...body, secretHash: "b".repeat(64) })).rejects.toThrow("credentials");
  await t.withIdentity({ subject: body.profileKey }).mutation(api.sharing.deleteMySharingProfile, {});
  await expect(send("synthetic-qa-bootstrap")).rejects.toThrow("credentials");
});

test("identical live invite retry is a write-free no-op with original expiry", async () => {
  const { t, owner, viewer } = await fixture();
  const tokenHash = "f".repeat(64);
  const first = await owner.mutation(api.sharing.createInvite, { tokenHash });
  const before = await t.run(async ctx => ctx.db.query("shareInvites").collect());
  vi.setSystemTime(Date.now() + 1000);
  expect(await owner.mutation(api.sharing.createInvite, { tokenHash })).toEqual(first);
  const invites = await t.run(async ctx => ctx.db.query("shareInvites").collect());
  expect(invites).toEqual(before);
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash, ownerDay: day });
  expect(await t.run(async ctx => (await ctx.db.query("shareRelationships").collect()).length)).toBe(1);
});

test.each(["foreign", "revoked", "accepted", "expired", "duplicates"])(
  "issuing a %s hash rejects before touching other pending invites",
  async kind => {
    const { t, ids, owner, stranger } = await fixture();
    const tokenHash = "a".repeat(64);
    await t.run(async ctx => {
      const statusByCase = new Map<string, "pending" | "revoked" | "accepted">([
        ["revoked", "revoked"],
        ["accepted", "accepted"],
        ["expired", "pending"],
        ["foreign", "pending"],
        ["duplicates", "pending"],
      ]);

      const status = statusByCase.get(kind) ?? "pending";

      const row = {
        ownerProfileId: kind === "foreign" ? ids[2] : ids[0], tokenHash,
        status,
        expiresAt: Date.now() + (kind === "expired" ? 0 : 10000), createdAt: Date.now(),
      };

      await ctx.db.insert("shareInvites", row);

      if (kind === "duplicates") await ctx.db.insert("shareInvites", row);
      await ctx.db.insert("shareInvites", { ...row, ownerProfileId: ids[0], tokenHash: "b".repeat(64), status: "pending", expiresAt: Date.now() + 10000 });
    });
    const before = await t.run(async ctx => ctx.db.query("shareInvites").collect());
    await expect(owner.mutation(api.sharing.createInvite, { tokenHash })).rejects.toThrow("unavailable");
    expect(await t.run(async ctx => ctx.db.query("shareInvites").collect())).toEqual(before);

    if (kind === "foreign") await expect(stranger.mutation(api.sharing.createInvite, { tokenHash: "b".repeat(64) })).rejects.toThrow("unavailable");
  },
);

test.each(["revoked", "expired", "two-live", "foreign-history"])(
  "historical %s rows never authorize; only one same-owner live candidate may be accepted",
  async kind => {
    const { t, ids, owner, viewer } = await fixture();
    const tokenHash = "c".repeat(64);
    await owner.mutation(api.sharing.createInvite, { tokenHash });
    await t.run(async ctx => {
      await ctx.db.insert("shareInvites", {
        ownerProfileId: kind === "foreign-history" ? ids[2] : ids[0], tokenHash,
        status: kind === "revoked" || kind === "foreign-history" ? "revoked" : "pending",
        expiresAt: Date.now() + (kind === "expired" ? 0 : 10000), createdAt: Date.now(),
      });
    });
    const before = await t.run(async ctx => ctx.db.query("shareInvites").collect());

    if (kind === "two-live" || kind === "foreign-history") {
      await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash, ownerDay: day })).rejects.toThrow("unavailable");
      expect(await t.run(async ctx => ctx.db.query("shareInvites").collect())).toEqual(before);
      expect(await t.run(async ctx => ctx.db.query("shareGrantIntervals").collect())).toEqual([]);
    } else {
      await viewer.mutation(api.sharing.acceptInvite, { tokenHash, ownerDay: day });
      await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash, ownerDay: day })).rejects.toThrow("unavailable");
      const after = await t.run(async ctx => ctx.db.query("shareInvites").collect());
      expect(after.find(row => row._id === before[1]._id)).toEqual(before[1]);
    }
  },
);

test("an accepted invite hash cannot replay through a same-owner pending duplicate", async () => {
  const { t, ids, viewer } = await fixture();
  const tokenHash = "d".repeat(64);
  await t.run(async ctx => {
    const relationshipId = await ctx.db.insert("shareRelationships", {
      profileAId: ids[0],
      profileBId: ids[2],
      pairKey: "owner:stranger",
      createdAt: Date.now(),
    });

    await ctx.db.insert("shareGrantIntervals", {
      relationshipId,
      fromProfileId: ids[0],
      toProfileId: ids[2],
      scope: { macros: true },
      startDay: day,
      startedAt: Date.now(),
    });
    await ctx.db.insert("shareInvites", {
      ownerProfileId: ids[0],
      tokenHash,
      status: "accepted",
      expiresAt: Date.now() + 10_000,
      createdAt: Date.now() - 1_000,
      acceptedAt: Date.now() - 500,
      acceptedByProfileId: ids[2],
    });
    await ctx.db.insert("shareInvites", {
      ownerProfileId: ids[0],
      tokenHash,
      status: "pending",
      expiresAt: Date.now() + 10_000,
      createdAt: Date.now(),
    });
  });

  const before = await t.run(async ctx => ({
    invites: await ctx.db.query("shareInvites").collect(),
    relationships: await ctx.db.query("shareRelationships").collect(),
    grants: await ctx.db.query("shareGrantIntervals").collect(),
  }));

  await expect(viewer.mutation(api.sharing.acceptInvite, { tokenHash, ownerDay: day })).rejects.toThrow("unavailable");
  expect(await t.run(async ctx => ({
    invites: await ctx.db.query("shareInvites").collect(),
    relationships: await ctx.db.query("shareRelationships").collect(),
    grants: await ctx.db.query("shareGrantIntervals").collect(),
  }))).toEqual(before);
});
