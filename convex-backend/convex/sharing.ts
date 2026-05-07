import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireCurrentProfile } from "./authHelpers";
import {
  assertCurrentDayKey,
  MACROS_SCOPE,
  assertDayKey,
  assertTokenHash,
  assertValidSnapshot,
  canonicalPairKey,
  closeIntervalEndDay,
  isDayVisibleFromIntervals,
  normalizeDisplayName,
} from "./sharingModel";

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export const updateDisplayName = mutation({
  args: { displayName: v.string() },
  handler: async (ctx, args) => {
    const profile = await requireCurrentProfile(ctx);
    const displayName = normalizeDisplayName(args.displayName);
    await ctx.db.patch(profile._id, { displayName, updatedAt: Date.now() });
    return { ok: true };
  },
});

export const createInvite = mutation({
  args: { tokenHash: v.string() },
  handler: async (ctx, args) => {
    assertTokenHash(args.tokenHash);
    const profile = await requireCurrentProfile(ctx);
    const now = Date.now();
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
  handler: async (ctx, args) => {
    assertDayKey(args.ownerDay);
    assertTokenHash(args.tokenHash);
    const viewer = await requireCurrentProfile(ctx);
    const invite = await ctx.db
      .query("shareInvites")
      .withIndex("by_token_hash", (q) => q.eq("tokenHash", args.tokenHash))
      .unique();

    if (invite == null || invite.status !== "pending" || invite.expiresAt <= Date.now()) {
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
  handler: async (ctx, args) => {
    assertDayKey(args.ownerDay);
    const profile = await requireCurrentProfile(ctx);
    const relationship = await relationshipForPair(ctx, profile._id, args.toProfileId);
    if (relationship == null || relationship.removedAt != null) {
      throw new Error("Relationship unavailable.");
    }

    if (args.enabled) {
      if ((await openGrantBetween(ctx, profile._id, args.toProfileId)) == null) {
        await ctx.db.insert("shareGrantIntervals", {
          relationshipId: relationship._id,
          fromProfileId: profile._id,
          toProfileId: args.toProfileId,
          scope: MACROS_SCOPE,
          startDay: args.ownerDay,
          startedAt: Date.now(),
        });
      }
    } else {
      await closeOpenGrants(ctx, profile._id, args.toProfileId, args.ownerDay);
    }
    return { ok: true };
  },
});

export const stopSharingMyData = mutation({
  args: { ownerDay: v.string() },
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
    return { ok: true };
  },
});

export const removePerson = mutation({
  args: { otherProfileId: v.id("profiles"), ownerDay: v.string() },
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
    return { ok: true };
  },
});

export const upsertMyDailySnapshot = mutation({
  args: {
    day: v.string(),
    timeZoneId: v.string(),
    calories: v.number(),
    protein: v.number(),
    fat: v.number(),
    carbs: v.number(),
    entryCount: v.number(),
  },
  handler: async (ctx, args) => {
    const profile = await requireCurrentProfile(ctx);
    assertValidSnapshot(args);
    const now = Date.now();
    const existing = await ctx.db
      .query("dailySnapshots")
      .withIndex("by_owner_day", (q) => q.eq("ownerProfileId", profile._id).eq("day", args.day))
      .unique();
    const snapshot = { ownerProfileId: profile._id, ...args, updatedAt: now };
    if (existing != null) {
      await ctx.db.patch(existing._id, snapshot);
      return { snapshotId: existing._id };
    }
    return { snapshotId: await ctx.db.insert("dailySnapshots", snapshot) };
  },
});

export const deleteMySharingProfile = mutation({
  args: {},
  handler: async (ctx) => {
    const profile = await requireCurrentProfile(ctx);
    const now = Date.now();
    const ownedInvites = (
      await Promise.all(
        (["pending", "accepted", "revoked"] as const).map((status) =>
          ctx.db
            .query("shareInvites")
            .withIndex("by_owner_status", (q) => q.eq("ownerProfileId", profile._id).eq("status", status))
            .collect(),
        ),
      )
    ).flat();
    const acceptedInvites = await ctx.db
      .query("shareInvites")
      .withIndex("by_accepted_by", (q) => q.eq("acceptedByProfileId", profile._id))
      .collect();
    const ownedSnapshots = await ctx.db
      .query("dailySnapshots")
      .withIndex("by_owner_day", (q) => q.eq("ownerProfileId", profile._id))
      .collect();
    const outgoing = await ctx.db
      .query("shareGrantIntervals")
      .withIndex("by_from_to", (q) => q.eq("fromProfileId", profile._id))
      .collect();
    const incoming = await ctx.db
      .query("shareGrantIntervals")
      .withIndex("by_to_from", (q) => q.eq("toProfileId", profile._id))
      .collect();
    const relationships = [
      ...(await ctx.db.query("shareRelationships").withIndex("by_profile_a", (q) => q.eq("profileAId", profile._id)).collect()),
      ...(await ctx.db.query("shareRelationships").withIndex("by_profile_b", (q) => q.eq("profileBId", profile._id)).collect()),
    ];
    const relationshipGrants = (
      await Promise.all(
        relationships.map((relationship) =>
          ctx.db.query("shareGrantIntervals").withIndex("by_relationship", (q) => q.eq("relationshipId", relationship._id)).collect(),
        ),
      )
    ).flat();
    const grants = uniqueById([...outgoing, ...incoming, ...relationshipGrants]);
    const invites = uniqueById([...ownedInvites, ...acceptedInvites]);

    await Promise.all([
      ...invites.map((invite) => ctx.db.delete(invite._id)),
      ...ownedSnapshots.map((snapshot) => ctx.db.delete(snapshot._id)),
      ...grants.map((grant) => ctx.db.delete(grant._id)),
      ...relationships.map((relationship) => ctx.db.delete(relationship._id)),
    ]);

    await ctx.db.patch(profile._id, {
      displayName: "Deleted sharing profile",
      secretHash: `deleted:${profile._id}`,
      deletedAt: now,
      updatedAt: now,
    });
    return { ok: true };
  },
});

export const sharingDashboard = query({
  args: { day: v.string(), ownerToday: v.string() },
  handler: async (ctx, args) => {
    assertDayKey(args.day);
    assertDayKey(args.ownerToday);
    if (args.day !== args.ownerToday) {
      throw new Error("Dashboard is current-day only.");
    }
    assertCurrentDayKey(args.day);
    const viewer = await requireCurrentProfile(ctx);
    const relationships = [
      ...(await ctx.db.query("shareRelationships").withIndex("by_profile_a", (q) => q.eq("profileAId", viewer._id)).collect()),
      ...(await ctx.db.query("shareRelationships").withIndex("by_profile_b", (q) => q.eq("profileBId", viewer._id)).collect()),
    ].filter((relationship) => relationship.removedAt == null);

    const people = await Promise.all(
      relationships.map(async (relationship) => {
        const otherId = relationship.profileAId === viewer._id ? relationship.profileBId : relationship.profileAId;
        const other = await ctx.db.get(otherId);
        if (other == null || other.deletedAt != null) {
          return null;
        }

        const incoming = await ctx.db
          .query("shareGrantIntervals")
          .withIndex("by_from_to", (q) => q.eq("fromProfileId", otherId).eq("toProfileId", viewer._id))
          .collect();
        const outgoing = await ctx.db
          .query("shareGrantIntervals")
          .withIndex("by_from_to", (q) => q.eq("fromProfileId", viewer._id).eq("toProfileId", otherId))
          .collect();
        const visible = isDayVisibleFromIntervals(args.day, args.ownerToday, incoming);
        const snapshot = visible
          ? await ctx.db
              .query("dailySnapshots")
              .withIndex("by_owner_day", (q) => q.eq("ownerProfileId", otherId).eq("day", args.day))
              .unique()
          : null;

        return {
          relationshipId: relationship._id,
          profileId: otherId,
          displayName: other.displayName,
          incomingActive: incoming.some((grant) => grant.endedAt == null),
          outgoingActive: outgoing.some((grant) => grant.endedAt == null),
          scope: MACROS_SCOPE,
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

async function openGrantBetween(ctx: MutationCtx, fromProfileId: Id<"profiles">, toProfileId: Id<"profiles">) {
  const grants = await ctx.db
    .query("shareGrantIntervals")
    .withIndex("by_from_to", (q) => q.eq("fromProfileId", fromProfileId).eq("toProfileId", toProfileId))
    .collect();
  return grants.find((grant) => grant.endedAt == null) ?? null;
}

async function closeOpenGrants(ctx: MutationCtx, fromProfileId: Id<"profiles">, toProfileId: Id<"profiles">, ownerDay: string) {
  const grants = await ctx.db
    .query("shareGrantIntervals")
    .withIndex("by_from_to", (q) => q.eq("fromProfileId", fromProfileId).eq("toProfileId", toProfileId))
    .collect();
  const now = Date.now();
  await Promise.all(
    grants
      .filter((grant) => grant.endedAt == null)
      .map((grant) =>
        ctx.db.patch(grant._id, {
          endDay: closeIntervalEndDay(ownerDay),
          endedAt: now,
        }),
      ),
  );
}

function uniqueById<T extends { _id: string }>(documents: T[]) {
  return [...new Map(documents.map((document) => [document._id, document])).values()];
}
