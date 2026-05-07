import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  profiles: defineTable({
    profileKey: v.string(),
    displayName: v.string(),
    secretHash: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
    deletedAt: v.optional(v.number()),
  }).index("by_profile_key", ["profileKey"]),

  dailySnapshots: defineTable({
    ownerProfileId: v.id("profiles"),
    day: v.string(),
    timeZoneId: v.string(),
    calories: v.number(),
    protein: v.number(),
    fat: v.number(),
    carbs: v.number(),
    entryCount: v.number(),
    updatedAt: v.number(),
  }).index("by_owner_day", ["ownerProfileId", "day"]),

  shareInvites: defineTable({
    ownerProfileId: v.id("profiles"),
    tokenHash: v.string(),
    status: v.union(v.literal("pending"), v.literal("accepted"), v.literal("revoked")),
    expiresAt: v.number(),
    createdAt: v.number(),
    acceptedAt: v.optional(v.number()),
    acceptedByProfileId: v.optional(v.id("profiles")),
  })
    .index("by_owner_status", ["ownerProfileId", "status"])
    .index("by_accepted_by", ["acceptedByProfileId"])
    .index("by_token_hash", ["tokenHash"]),

  shareRelationships: defineTable({
    profileAId: v.id("profiles"),
    profileBId: v.id("profiles"),
    pairKey: v.string(),
    createdAt: v.number(),
    removedAt: v.optional(v.number()),
  })
    .index("by_pair_key", ["pairKey"])
    .index("by_profile_a", ["profileAId"])
    .index("by_profile_b", ["profileBId"]),

  shareGrantIntervals: defineTable({
    relationshipId: v.id("shareRelationships"),
    fromProfileId: v.id("profiles"),
    toProfileId: v.id("profiles"),
    scope: v.object({ macros: v.boolean() }),
    startDay: v.string(),
    endDay: v.optional(v.string()),
    startedAt: v.number(),
    endedAt: v.optional(v.number()),
  })
    .index("by_from_to", ["fromProfileId", "toProfileId"])
    .index("by_to_from", ["toProfileId", "fromProfileId"])
    .index("by_relationship", ["relationshipId"]),
});
