/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

const modules = import.meta.glob("../**/*.ts");

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
  expect((await viewer.query(api.sharing.sharingDashboard, { day, ownerToday: day })).people).toEqual([]);
  await expect(owner.mutation(api.sharing.upsertMyDailySnapshot, snapshot)).rejects.toThrow("unavailable");
  expect(await t.run(async ctx => ({
    invites: (await ctx.db.query("shareInvites").collect()).length,
    grants: (await ctx.db.query("shareGrantIntervals").collect()).length,
    relationships: (await ctx.db.query("shareRelationships").collect()).length,
    snapshots: (await ctx.db.query("dailySnapshots").collect()).length,
  }))).toEqual({ invites: 0, grants: 0, relationships: 0, snapshots: 1 });
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
