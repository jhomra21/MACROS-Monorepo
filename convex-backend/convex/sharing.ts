import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { consumeProfileQuota } from "./quotas";
import { internal } from "./_generated/api";
import { requireCurrentProfile } from "./authHelpers";
import { activeConnection, connectionActive, hasPro, requireProEnabled } from "./proModel";
import { recomputeProfile } from "./proStatus";
import { clearFoodsWithoutRecipients, openGrantBetween, syncDay } from "./foodSharing";
import { dashboardResult, foodInput, okResult, personDayResult, scopeName, snapshotFields, snapshotInput, snapshotResult } from "./sharingValidators";
import {
  assertCurrentDayKey,
  MACROS_SCOPE,
  assertDayKey,
  assertTokenHash,
  canonicalPairKey,
  closeIntervalEndDay,
  isDayVisibleFromIntervals,
  normalizeDisplayName,
} from "./sharingModel";

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export const updateDisplayName = mutation({
  args: { displayName: v.string() },
  returns: okResult,
  handler: async (ctx, args) => {
    const profile = await requireCurrentProfile(ctx);
    const displayName = normalizeDisplayName(args.displayName);
    await consumeProfileQuota(ctx, profile._id, "displayNameUpdates");
    await ctx.db.patch(profile._id, { displayName, updatedAt: Date.now() });

    return { ok: true };
  },
});

export const createInvite = mutation({
  args: { tokenHash: v.string() },
  returns: v.object({ inviteId: v.id("shareInvites"), expiresAt: v.number() }),
  handler: async (ctx, args) => {
    assertTokenHash(args.tokenHash);
    const profile = await requireCurrentProfile(ctx);
    const now = Date.now();

    if (await requireProEnabled(ctx) && !await hasPro(ctx, profile._id)) {
      throw new Error("MACROS Pro is required to create an invite.");
    }

    const matches = await ctx.db
      .query("shareInvites")
      .withIndex("by_token_hash", (q) => q.eq("tokenHash", args.tokenHash))
      .collect();

    if (matches.length > 0) {
      const [existing] = matches;

      // A hash is never reassigned or revived. Retry only its single live issuance.
      if (matches.length !== 1 || existing.ownerProfileId !== profile._id ||
        existing.status !== "pending" || existing.expiresAt <= now) {
        throw new Error("Invite is unavailable.");
      }

      return { inviteId: existing._id, expiresAt: existing.expiresAt };
    }

    await consumeProfileQuota(ctx, profile._id, "invitesCreated");

    const pending = await ctx.db
      .query("shareInvites")
      .withIndex("by_owner_status", (q) => q.eq("ownerProfileId", profile._id).eq("status", "pending"))
      .collect();

    await Promise.all(pending.map((invite) => ctx.db.patch(invite._id, { status: "revoked" })));

    const inviteId = await ctx.db.insert("shareInvites", {
      ownerProfileId: profile._id,
      tokenHash: args.tokenHash,
      status: "pending",
      expiresAt: now + INVITE_TTL_MS,
      createdAt: now,
    });

    return { inviteId, expiresAt: now + INVITE_TTL_MS };
  },
});

export const revokePendingInvite = mutation({
  args: { inviteId: v.id("shareInvites") },
  returns: okResult,
  handler: async (ctx, args) => {
    const profile = await requireCurrentProfile(ctx);
    const invite = await ctx.db.get(args.inviteId);

    if (invite == null || invite.ownerProfileId !== profile._id || invite.status !== "pending") {
      throw new Error("Invite is unavailable.");
    }

    await ctx.db.patch(invite._id, { status: "revoked" });

    return { ok: true };
  },
});

export const acceptInvite = mutation({
  args: { tokenHash: v.string(), ownerDay: v.string() },
  returns: v.record(v.string(), v.string()),
  handler: async (ctx, args) => {
    assertDayKey(args.ownerDay);
    assertTokenHash(args.tokenHash);
    const viewer = await requireCurrentProfile(ctx);

    const matches = await ctx.db
      .query("shareInvites")
      .withIndex("by_token_hash", (q) => q.eq("tokenHash", args.tokenHash))
      .collect();

    const live = matches.filter((invite) => invite.status === "pending" && invite.expiresAt > Date.now());
    const [invite] = live;

    // A consumed hash never authorizes again, even if a pending duplicate exists.
    if (live.length !== 1 || matches.some((row) =>
      row.status === "accepted" || row.ownerProfileId !== invite.ownerProfileId)) {
      throw new Error("Invite is unavailable.");
    }

    const owner = await ctx.db.get(invite.ownerProfileId);

    if (owner == null || owner.deletedAt != null || owner._id === viewer._id) {
      throw new Error("Invite is unavailable.");
    }

    const pairKey = canonicalPairKey(owner.profileKey, viewer.profileKey);
    const relationship = await consolidatedRelationshipForPairKey(ctx, pairKey);

    const now = Date.now();

    const [profileAId, profileBId] = owner.profileKey < viewer.profileKey
      ? [owner._id, viewer._id]
      : [viewer._id, owner._id];

    let relationshipId: Id<"shareRelationships">;

    if (relationship == null) {
      relationshipId = await ctx.db.insert("shareRelationships", { profileAId, profileBId, pairKey, createdAt: now });
    } else if (relationship.removedAt != null) {
      relationshipId = relationship._id;
      await ctx.db.patch(relationship._id, { removedAt: undefined });
    } else {
      relationshipId = relationship._id;
    }

    const openGrant = await openGrantBetween(ctx, owner._id, viewer._id);

    if (openGrant == null) {
      await ctx.db.insert("shareGrantIntervals", {
        relationshipId,
        fromProfileId: owner._id,
        toProfileId: viewer._id,
        scope: MACROS_SCOPE,
        startDay: args.ownerDay,
        startedAt: now,
      });
    }

    await ctx.db.patch(invite._id, {
      status: "accepted",
      acceptedAt: now,
      acceptedByProfileId: viewer._id,
    });

    return { relationshipId };
  },
});

export const setOutgoingSharingForPerson = mutation({
  args: { toProfileId: v.id("profiles"), enabled: v.boolean(), ownerDay: v.string() },
  returns: okResult,
  handler: async (ctx, args) => changeOutgoingScope(ctx, args.toProfileId, args.enabled ? "macros" : "off", args.ownerDay),
});

export const setOutgoingScope = mutation({
  args: { otherProfileId: v.id("profiles"), scope: scopeName, ownerDay: v.optional(v.string()) },
  returns: okResult,
  handler: async (ctx, args) => changeOutgoingScope(ctx, args.otherProfileId, args.scope, args.ownerDay ?? new Date().toISOString().slice(0, 10)),
});

async function changeOutgoingScope(
  ctx: MutationCtx, otherProfileId: Id<"profiles">, scope: "off" | "macros" | "macrosAndFoods", ownerDay: string,
) {
  assertDayKey(ownerDay);
  const profile = await requireCurrentProfile(ctx);
  const other = await ctx.db.get(otherProfileId);
  const relationship = await relationshipForPair(ctx, profile._id, otherProfileId);

  if (!other || other.deletedAt != null || relationship == null || relationship.removedAt != null) {
    throw new Error("Relationship unavailable.");
  }

  const open = await openGrantBetween(ctx, profile._id, otherProfileId);

  if (scope === "off") {
    await closeOpenGrants(ctx, profile._id, otherProfileId, ownerDay);
  } else if (open?.scope.macros) {
    await ctx.db.patch(open._id, { scope: { macros: true, foods: scope === "macrosAndFoods" } });
  } else {
    if (open) await closeOpenGrants(ctx, profile._id, otherProfileId, ownerDay);
    await ctx.db.insert("shareGrantIntervals", {
      relationshipId: relationship._id, fromProfileId: profile._id, toProfileId: otherProfileId,
      scope: { macros: true, foods: scope === "macrosAndFoods" }, startDay: ownerDay, startedAt: Date.now(),
    });
  }

  if (scope !== "macrosAndFoods") await clearFoodsWithoutRecipients(ctx, profile._id, ownerDay);

  return { ok: true };
}

export const stopSharingMyData = mutation({
  args: { ownerDay: v.string() },
  returns: okResult,
  handler: async (ctx, args) => {
    assertDayKey(args.ownerDay);
    const profile = await requireCurrentProfile(ctx);

    const open = await ctx.db
      .query("shareGrantIntervals")
      .withIndex("by_from_to", (q) => q.eq("fromProfileId", profile._id))
      .collect();

    await Promise.all(
      open
        .filter((grant) => grant.endedAt == null)
        .map((grant) =>
          ctx.db.patch(grant._id, {
            endDay: closeIntervalEndDay(args.ownerDay),
            endedAt: Date.now(),
          }),
        ),
    );
    await clearFoodsWithoutRecipients(ctx, profile._id, args.ownerDay);

    return { ok: true };
  },
});

export const removePerson = mutation({
  args: { otherProfileId: v.id("profiles"), ownerDay: v.string() },
  returns: okResult,
  handler: async (ctx, args) => {
    assertDayKey(args.ownerDay);
    const profile = await requireCurrentProfile(ctx);
    const relationship = await relationshipForPair(ctx, profile._id, args.otherProfileId);

    if (relationship == null || relationship.removedAt != null) {
      throw new Error("Relationship unavailable.");
    }

    const now = Date.now();

    const grants = await ctx.db
      .query("shareGrantIntervals")
      .withIndex("by_relationship", (q) => q.eq("relationshipId", relationship._id))
      .collect();

    await Promise.all([
      ...grants.map((grant) => ctx.db.delete(grant._id)),
      ctx.db.patch(relationship._id, { removedAt: now }),
    ]);
    await clearFoodsWithoutRecipients(ctx, profile._id, args.ownerDay);
    await clearFoodsWithoutRecipients(ctx, args.otherProfileId, args.ownerDay);

    return { ok: true };
  },
});

export const upsertMyDailySnapshot = mutation({
  args: snapshotFields,
  returns: snapshotResult,
  handler: async (ctx, args) => syncDay(ctx, (await requireCurrentProfile(ctx))._id, args),
});

export const syncMyDay = mutation({
  args: { snapshot: snapshotInput, foods: v.optional(v.array(foodInput)) },
  returns: snapshotResult,
  handler: async (ctx, args) => syncDay(ctx, (await requireCurrentProfile(ctx))._id, args.snapshot, args.foods),
});

export const deleteMySharingProfile = mutation({
  args: {},
  returns: okResult,
  handler: async ctx => {
    const profile = await requireCurrentProfile(ctx);
    const now = Date.now();
    await ctx.db.patch(profile._id, {
      displayName: "Deleted sharing profile", secretHash: `deleted:${profile._id}`, deletedAt: now, updatedAt: now,
    });
    await recomputeProfile(ctx, profile._id);
    await ctx.scheduler.runAfter(0, internal.profileDeletion.deleteBatch, { profileId: profile._id, stage: 0 });

    return { ok: true };
  },
});

export const sharingDashboard = query({
  args: { day: v.string(), ownerToday: v.string() },
  returns: dashboardResult,
  handler: async (ctx, args) => {
    assertDayKey(args.day);
    assertDayKey(args.ownerToday);

    if (args.day !== args.ownerToday) {
      throw new Error("Dashboard is current-day only.");
    }

    assertCurrentDayKey(args.day);
    const viewer = await requireCurrentProfile(ctx);

    const requirePro = await requireProEnabled(ctx);
    const viewerPro = await hasPro(ctx, viewer._id);

    const asA = await ctx.db.query("shareRelationships").withIndex("by_profile_a_removed",
      q => q.eq("profileAId", viewer._id).eq("removedAt", undefined)).take(100);

    const asB = await ctx.db.query("shareRelationships").withIndex("by_profile_b_removed",
      q => q.eq("profileBId", viewer._id).eq("removedAt", undefined)).take(100 - asA.length);

    const relationships = [...asA, ...asB];

    const people = await Promise.all(
      relationships.map(async (relationship) => {
        const otherId = relationship.profileAId === viewer._id ? relationship.profileBId : relationship.profileAId;
        const other = await ctx.db.get(otherId);

        if (other == null || other.deletedAt != null) {
          return null;
        }

        const [incoming, outgoing, otherPro] = await Promise.all([
          openGrantBetween(ctx, otherId, viewer._id), openGrantBetween(ctx, viewer._id, otherId),
          requirePro && !viewerPro ? hasPro(ctx, otherId) : false,
        ]);

        const active = connectionActive(requirePro, viewerPro, otherPro);

        const visible = active && !!incoming?.scope.macros &&
          isDayVisibleFromIntervals(args.day, args.ownerToday, [incoming]);

        const snapshot = visible
          ? await ctx.db
              .query("dailySnapshots")
              .withIndex("by_owner_day", (q) => q.eq("ownerProfileId", otherId).eq("day", args.day))
              .unique()
          : null;

        const outgoingScope: "off" | "macros" | "macrosAndFoods" = !outgoing?.scope.macros
          ? "off" : outgoing.scope.foods ? "macrosAndFoods" : "macros";

        return {
          relationshipId: relationship._id,
          profileId: otherId,
          displayName: other.displayName,
          incomingActive: incoming != null,
          outgoingActive: outgoing != null,
          scope: MACROS_SCOPE,
          foodsShared: visible && incoming?.scope.foods === true,
          connectionPaused: !active,
          outgoingScope,
          snapshot: snapshot == null ? null : {
            day: snapshot.day,
            timeZoneId: snapshot.timeZoneId,
            calories: snapshot.calories,
            protein: snapshot.protein,
            fat: snapshot.fat,
            carbs: snapshot.carbs,
            entryCount: snapshot.entryCount,
            updatedAt: snapshot.updatedAt,
          },
        };
      }),
    );

    return {
      people: people.filter((person) => person != null).sort((a, b) => a.displayName.localeCompare(b.displayName)),
    };
  },
});

export const personDay = query({
  args: { otherProfileId: v.id("profiles"), day: v.string(), ownerToday: v.string() },
  returns: personDayResult,
  handler: async (ctx, args) => {
    assertDayKey(args.ownerToday);

    if (args.day !== args.ownerToday) throw new Error("Person day is current-day only.");
    assertCurrentDayKey(args.day);
    const viewer = await requireCurrentProfile(ctx);
    const other = await ctx.db.get(args.otherProfileId);

    if (!other || other.deletedAt != null || other._id === viewer._id) throw new Error("Relationship unavailable.");

    const relationships = await ctx.db.query("shareRelationships").withIndex("by_pair_key",
      q => q.eq("pairKey", canonicalPairKey(viewer.profileKey, other.profileKey))).collect();

    if (!relationships.some(row => row.removedAt == null)) throw new Error("Relationship unavailable.");

    if (!await activeConnection(ctx, viewer._id, other._id)) throw new Error("Connection paused.");
    const incoming = await openGrantBetween(ctx, other._id, viewer._id);

    if (!incoming?.scope.macros || !isDayVisibleFromIntervals(args.day, args.ownerToday, [incoming])) {
      throw new Error("Shared day unavailable.");
    }

    const snapshot = await ctx.db.query("dailySnapshots").withIndex("by_owner_day",
      q => q.eq("ownerProfileId", other._id).eq("day", args.day)).unique();

    const foodDay = incoming.scope.foods === true ? await ctx.db.query("sharedFoodDays").withIndex("by_owner_day",
      q => q.eq("ownerProfileId", other._id).eq("day", args.day)).unique() : null;

    return {
      snapshot: snapshot == null ? null : {
        day: snapshot.day, timeZoneId: snapshot.timeZoneId, calories: snapshot.calories, protein: snapshot.protein,
        fat: snapshot.fat, carbs: snapshot.carbs, entryCount: snapshot.entryCount, updatedAt: snapshot.updatedAt,
      },
      foods: (foodDay?.foods ?? []).slice().sort((a, b) => a.sortIndex - b.sortIndex),
    };
  },
});

async function relationshipForPair(ctx: MutationCtx, profileAId: Id<"profiles">, profileBId: Id<"profiles">) {
  const profileA = await ctx.db.get(profileAId);
  const profileB = await ctx.db.get(profileBId);

  if (profileA == null || profileB == null) {
    return null;
  }

  const pairKey = canonicalPairKey(profileA.profileKey, profileB.profileKey);

  return await consolidatedRelationshipForPairKey(ctx, pairKey);
}

async function consolidatedRelationshipForPairKey(ctx: MutationCtx, pairKey: string) {
  const relationships = await ctx.db.query("shareRelationships").withIndex("by_pair_key", (q) => q.eq("pairKey", pairKey)).collect();

  if (relationships.length <= 1) {
    return relationships[0] ?? null;
  }

  const sorted = [...relationships].sort((a, b) => a.createdAt - b.createdAt);
  const primary = sorted.find((relationship) => relationship.removedAt == null) ?? sorted[0];
  const duplicates = sorted.filter((relationship) => relationship._id !== primary._id);

  const duplicateGrants = (
    await Promise.all(
      duplicates.map((relationship) =>
        ctx.db.query("shareGrantIntervals").withIndex("by_relationship", (q) => q.eq("relationshipId", relationship._id)).collect(),
      ),
    )
  ).flat();

  await Promise.all([
    ...duplicateGrants.map((grant) => ctx.db.patch(grant._id, { relationshipId: primary._id })),
    ...duplicates.map((relationship) => ctx.db.delete(relationship._id)),
  ]);

  return primary;
}

async function closeOpenGrants(ctx: MutationCtx, fromProfileId: Id<"profiles">, toProfileId: Id<"profiles">, ownerDay: string) {
  const grants = await ctx.db
    .query("shareGrantIntervals")
    .withIndex("by_from_to_ended", (q) => q.eq("fromProfileId", fromProfileId).eq("toProfileId", toProfileId).eq("endedAt", undefined))
    .collect();

  const now = Date.now();
  await Promise.all(
    grants.map((grant) =>
      ctx.db.patch(grant._id, {
        endDay: closeIntervalEndDay(ownerDay),
        endedAt: now,
      }),
    ),
  );
}
