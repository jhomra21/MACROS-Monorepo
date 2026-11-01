/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import { AppleVerifier } from "../_lib/appleVerifier.node";
import * as sharingFunctions from "../sharing";
import type { JWSTransactionDecodedPayload, JWSRenewalInfoDecodedPayload } from "@apple/app-store-server-library";

const modules = import.meta.glob("../**/*.ts");

const day = "2026-10-13";

const start = Date.parse(`${day}T12:00:00Z`);

const dashboardArgs = { day, ownerToday: day };

const transaction = (extra: Partial<JWSTransactionDecodedPayload> = {}): JWSTransactionDecodedPayload => ({
  bundleId: "juan-test.cal-macro-tracker", environment: "Sandbox",
  productId: "macros.pro.monthly", originalTransactionId: "purchase",
  transactionId: "period-1", signedDate: start, expiresDate: start + 1000, ...extra,
});

const lifetime = transaction({ productId: "macros.pro.lifetime", expiresDate: undefined });

const renewal = (extra: Partial<JWSRenewalInfoDecodedPayload> = {}): JWSRenewalInfoDecodedPayload => ({
  environment: "Sandbox", productId: "macros.pro.monthly", originalTransactionId: "purchase",
  signedDate: start, ...extra,
});

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(start);
  // Only Apple's cryptographic verifier is mocked, not application policy or DB reads.
  vi.spyOn(AppleVerifier.prototype, "transaction").mockImplementation(async value => JSON.parse(value));
  vi.spyOn(AppleVerifier.prototype, "renewal").mockImplementation(async value => JSON.parse(value));
  vi.spyOn(AppleVerifier.prototype, "notification").mockImplementation(async value => JSON.parse(value));
});

afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers(); });

async function fixture() {
  const t = convexTest(schema, modules);

  const ids = await t.run(async ctx => {
    const result = [];

    for (const key of ["owner", "viewer", "new-profile"]) {
      result.push(await ctx.db.insert("profiles", {
        profileKey: key, displayName: key, secretHash: "fixture", createdAt: start, updatedAt: start,
      }));
    }

    return result;
  });

  const owner = t.withIdentity({ subject: "owner" });
  const viewer = t.withIdentity({ subject: "viewer" });
  const newcomer = t.withIdentity({ subject: "new-profile" });
  await owner.mutation(api.sharing.createInvite, { tokenHash: "a".repeat(64) });
  await viewer.mutation(api.sharing.acceptInvite, { tokenHash: "a".repeat(64), ownerDay: day });
  await t.run(ctx => ctx.db.insert("settings", { sharingRequirePro: true }));

  const submit = (tx = transaction(), info?: ReturnType<typeof renewal>) => owner.action(api.entitlements.submitPurchase, {
    signedTransaction: JSON.stringify(tx), signedRenewalInfo: info && JSON.stringify(info),
  });

  const notify = (type: string, tx = transaction(), info?: ReturnType<typeof renewal>, signedDate = tx.signedDate) =>
    t.fetch("/appstore/notifications", { method: "POST", body: JSON.stringify({
      signedPayload: JSON.stringify({ notificationType: type, signedDate, data: {
        environment: "Sandbox", signedTransactionInfo: JSON.stringify(tx),
        signedRenewalInfo: info && JSON.stringify(info),
      } }),
    }) });

  const paused = async () => (await viewer.query(api.sharing.sharingDashboard, dashboardArgs)).people[0].connectionPaused;

  return { t, ids, owner, viewer, newcomer, submit, notify, paused };
}

test("review: refund survives deletion of the last profile and rejects lifetime replay", async () => {
  const { t, owner, newcomer, submit, notify } = await fixture();
  await submit(lifetime);
  expect((await notify("REFUND", { ...lifetime, signedDate: start + 1, revocationDate: start })).status).toBe(200);
  await owner.mutation(api.sharing.deleteMySharingProfile, {});
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  await expect(newcomer.action(api.entitlements.submitPurchase, {
    signedTransaction: JSON.stringify(lifetime),
  })).rejects.toThrow("revoked");
  await expect(newcomer.mutation(api.sharing.createInvite, { tokenHash: "b".repeat(64) })).rejects.toThrow("Pro");
});

test("review: an unknown refund is retained and rejects the first submission", async () => {
  const { notify, submit, paused } = await fixture();
  expect((await notify("REFUND", { ...lifetime, signedDate: start + 1 })).status).toBe(200);
  await expect(submit(lifetime)).rejects.toThrow("revoked");
  expect(await paused()).toBe(true);
});

test("review: refund of an old subscription period leaves the paid renewal active", async () => {
  const { submit, notify, paused } = await fixture();
  await submit(transaction());
  await submit(transaction({ transactionId: "period-2", signedDate: start + 1, expiresDate: start + 10_000 }));
  await notify("REFUND", transaction({ signedDate: start + 2, revocationDate: start }));
  expect(await paused()).toBe(false);
});

test("review: transaction and renewal watermarks cannot poison coverage or its retry", async () => {
  const { submit, paused } = await fixture();
  const valid = transaction({ signedDate: start + 10, expiresDate: start + 10_000 });
  await submit(valid);
  await submit(transaction({ signedDate: start - 10, expiresDate: start - 1 }), renewal({ signedDate: start + 20 }));
  expect(await paused()).toBe(false);
  await submit(valid);
  expect(await paused()).toBe(false);
});

test("review: REFUND_REVERSED restores Pro and stale or equal refund events cannot undo it", async () => {
  const { submit, notify, paused } = await fixture();
  await submit(lifetime);
  await notify("REFUND", { ...lifetime, signedDate: start + 1 });
  expect(await paused()).toBe(true);
  await notify("REFUND_REVERSED", { ...lifetime, signedDate: start + 2, revocationDate: start });
  expect(await paused()).toBe(false);
  await notify("REFUND", { ...lifetime, signedDate: start + 1 });
  await notify("REVOKE", { ...lifetime, signedDate: start + 2 });
  expect(await paused()).toBe(false);
  await notify("REVOKE", { ...lifetime, signedDate: start + 3 });
  expect(await paused()).toBe(true);
  await notify("REFUND_REVERSED", { ...lifetime, signedDate: start + 2 });
  expect(await paused()).toBe(true);
});

test("review: scheduled expiry writes inactive Pro status and changes the dashboard to paused", async () => {
  const { t, ids, submit, paused } = await fixture();
  await submit();
  expect(await paused()).toBe(false);
  expect(await t.run(ctx => ctx.db.query("proStatus").withIndex("by_profile", q => q.eq("profileId", ids[0])).unique()))
    .toMatchObject({ active: true, activeUntil: start + 1000 });
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect(Date.now()).toBe(start + 1000);
  expect(await t.run(ctx => ctx.db.query("proStatus").withIndex("by_profile", q => q.eq("profileId", ids[0])).unique()))
    .toMatchObject({ active: false });
  expect(await paused()).toBe(true);
});

test("review: grace extends Pro through transaction expiry, then the scheduled grace expiry pauses it", async () => {
  const { t, submit, paused } = await fixture();
  await submit(transaction(), renewal({ gracePeriodExpiresDate: start + 3000 }));
  vi.advanceTimersByTime(1000);
  await t.finishInProgressScheduledFunctions();
  expect(await paused()).toBe(false);
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect(Date.now()).toBe(start + 3000);
  expect(await paused()).toBe(true);
});

test("review: an old scheduled expiry is harmless after a newer renewal", async () => {
  const { t, submit, paused } = await fixture();
  await submit();
  await submit(transaction({ transactionId: "period-2", signedDate: start + 1, expiresDate: start + 3000 }));
  vi.advanceTimersByTime(1000);
  await t.finishInProgressScheduledFunctions();
  expect(await paused()).toBe(false);
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  expect(await paused()).toBe(true);
});

test("review: a newer renewal has independent ordering, including clearing grace", async () => {
  const { submit, paused } = await fixture();
  const expired = transaction({ expiresDate: start - 1 });
  await submit(expired, renewal({ signedDate: start + 2, gracePeriodExpiresDate: start + 3000 }));
  expect(await paused()).toBe(false);
  await submit(expired, renewal({ signedDate: start + 1 }));
  expect(await paused()).toBe(false);
  await submit(expired, renewal({ signedDate: start + 3 }));
  expect(await paused()).toBe(true);
});

test("review: renewal grace cannot bypass a refunded subscription", async () => {
  const { submit, notify, paused } = await fixture();
  await submit();
  await notify("REFUND", transaction({ signedDate: start + 1 }));
  await expect(submit(transaction(), renewal({ signedDate: start + 2, gracePeriodExpiresDate: start + 5000 })))
    .rejects.toThrow("revoked");
  expect(await paused()).toBe(true);
});

test("review: dashboard reads at most 100 active relationships across both indexes and ignores removed rows", async () => {
  const { t, ids, viewer } = await fixture();
  await t.run(async ctx => {
    for (let i = 0; i < 240; i++) {
      const otherId = await ctx.db.insert("profiles", {
        profileKey: `person-${i}`, displayName: `person-${i}`, secretHash: "fixture", createdAt: start, updatedAt: start,
      });

      await ctx.db.insert("shareRelationships", {
        profileAId: i % 2 ? ids[1] : otherId, profileBId: i % 2 ? otherId : ids[1],
        pairKey: `pair-${i}`, createdAt: start, removedAt: i < 40 ? start : undefined,
      });
    }
  });
  const result = await viewer.query(api.sharing.sharingDashboard, dashboardArgs);
  expect(result.people).toHaveLength(100);
  expect(result.people.every(person => !/^person-([0-9]|[12][0-9]|3[0-9])$/.test(person.displayName))).toBe(true);
});

test("review: removed relationships never appear in the dashboard", async () => {
  const { viewer, ids } = await fixture();
  await viewer.mutation(api.sharing.removePerson, { otherProfileId: ids[0], ownerDay: day });
  expect(await viewer.query(api.sharing.sharingDashboard, dashboardArgs)).toEqual({ people: [] });
});

test("review: dead quota deletion export is removed", () => {
  expect(sharingFunctions).not.toHaveProperty("deleteProfileQuotaBatch");
});

test("review: five purchase links are atomic, retries keep slots, and deleting a profile frees its slot", async () => {
  const { t, owner, submit } = await fixture();
  await submit(lifetime);
  await submit(lifetime);

  for (let i = 1; i <= 5; i++) {
    const key = `cap-${i}`;
    await t.run(ctx => ctx.db.insert("profiles", {
      profileKey: key, displayName: key, secretHash: "fixture", createdAt: start, updatedAt: start,
    }));
    const call = t.withIdentity({ subject: key }).action(api.entitlements.submitPurchase, { signedTransaction: JSON.stringify(lifetime) });

    if (i === 5) await expect(call).rejects.toThrow("5");
    else await call;
  }

  await owner.mutation(api.sharing.deleteMySharingProfile, {});
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  await t.withIdentity({ subject: "cap-5" }).action(api.entitlements.submitPurchase, { signedTransaction: JSON.stringify(lifetime) });
  expect(await t.run(ctx => ctx.db.query("purchaseLinks").collect())).toHaveLength(5);
  expect(await t.run(ctx => ctx.db.query("appleTransactions").collect())).toHaveLength(1);
});

test("review: authenticated submission rejects a profile tombstoned during verification", async () => {
  const { owner, submit } = await fixture();
  vi.spyOn(AppleVerifier.prototype, "transaction").mockImplementationOnce(async value => {
    await owner.mutation(api.sharing.deleteMySharingProfile, {});

    return JSON.parse(value);
  });
  await expect(submit()).rejects.toThrow("unavailable");
});

test("review: same transaction or purchase cannot cross Apple environments", async () => {
  const { submit } = await fixture();
  await submit();
  await expect(submit(transaction({ environment: "Production" }))).rejects.toThrow("environment");
  await expect(submit(transaction({ transactionId: "period-2", environment: "Production" }))).rejects.toThrow("environment");
});

test("review: verified non-grant notifications still retain signed purchase and renewal state", async () => {
  const { notify, submit, paused } = await fixture();
  await notify("DID_CHANGE_RENEWAL_STATUS", transaction({ signedDate: start + 2, expiresDate: start + 5000 }),
    renewal({ signedDate: start + 3, autoRenewStatus: 0 }));
  await submit(transaction({ expiresDate: start - 1 }));
  expect(await paused()).toBe(false);
});

test("review: missing transaction IDs and renewal signed dates are rejected", async () => {
  const { submit } = await fixture();
  await expect(submit(transaction({ transactionId: undefined }))).rejects.toThrow("transaction");
  await expect(submit(transaction(), renewal({ signedDate: undefined }))).rejects.toThrow("signedDate");
});

test("review: explicit scheduled recompute remains harmless after profile cleanup", async () => {
  const { t, ids, submit, owner } = await fixture();
  await submit();
  await owner.mutation(api.sharing.deleteMySharingProfile, {});
  await t.finishAllScheduledFunctions(() => vi.runAllTimers());
  await t.mutation(internal.proStatus.recompute, { profileId: ids[0] });
  expect(await t.run(ctx => ctx.db.query("proStatus").collect())).toEqual([]);
});

test("review: a refunded latest period cannot borrow grace from an older unrevoked period", async () => {
  const { submit, notify, paused } = await fixture();
  await submit(transaction({ transactionId: "old-period", expiresDate: start - 2000 }));
  await submit(transaction({ expiresDate: start - 1 }), renewal({ gracePeriodExpiresDate: start + 5000 }));
  expect(await paused()).toBe(false);
  await notify("REFUND", transaction({ signedDate: start + 1, expiresDate: start - 1 }));
  expect(await paused()).toBe(true);
});

test("review: a full link cap cannot discard a verified refund submitted by a sixth profile", async () => {
  const { t, submit, newcomer, paused } = await fixture();
  await submit(lifetime);

  for (let i = 0; i < 4; i++) {
    const key = `refund-cap-${i}`;
    await t.run(ctx => ctx.db.insert("profiles", {
      profileKey: key, displayName: key, secretHash: "fixture", createdAt: start, updatedAt: start,
    }));
    await t.withIdentity({ subject: key }).action(api.entitlements.submitPurchase, { signedTransaction: JSON.stringify(lifetime) });
  }

  await expect(newcomer.action(api.entitlements.submitPurchase, {
    signedTransaction: JSON.stringify({ ...lifetime, signedDate: start + 1, revocationDate: start }),
  })).rejects.toThrow();
  expect(await paused()).toBe(true);
});

test("review: a sixth profile's verified renewal updates existing links without attaching the sixth profile", async () => {
  const { t, submit, newcomer, paused } = await fixture();
  await submit(transaction({ expiresDate: start - 1 }));

  for (let i = 0; i < 4; i++) {
    const key = `renewal-cap-${i}`;
    await t.run(ctx => ctx.db.insert("profiles", {
      profileKey: key, displayName: key, secretHash: "fixture", createdAt: start, updatedAt: start,
    }));
    await t.withIdentity({ subject: key }).action(api.entitlements.submitPurchase, {
      signedTransaction: JSON.stringify(transaction({ expiresDate: start - 1 })),
    });
  }

  expect(await paused()).toBe(true);
  await expect(newcomer.action(api.entitlements.submitPurchase, {
    signedTransaction: JSON.stringify(transaction({ transactionId: "period-2", signedDate: start + 1 })),
  })).rejects.toThrow("5");
  expect(await paused()).toBe(false);
  expect(await t.run(ctx => ctx.db.query("purchaseLinks").collect())).toHaveLength(5);
});
