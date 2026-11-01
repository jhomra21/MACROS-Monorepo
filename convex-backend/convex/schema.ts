import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { foodInput, renewalFields, transactionFields } from "./sharingValidators";

export default defineSchema({
  settings: defineTable({ sharingRequirePro: v.boolean() }),

  // Retained anti-replay state, never deleted with profiles. These records hold
  // no personal data beyond Apple's transaction IDs and purchase metadata.
  appleTransactions: defineTable(transactionFields)
    .index("by_transaction", ["transactionId"])
    .index("by_original", ["originalTransactionId"]),

  appleRenewals: defineTable({
    originalTransactionId: v.string(),
    ...renewalFields,
  }).index("by_original", ["originalTransactionId"]),

  purchaseLinks: defineTable({
    originalTransactionId: v.string(), profileId: v.id("profiles"),
  }).index("by_original", ["originalTransactionId"]).index("by_profile", ["profileId"]),

  proStatus: defineTable({
    profileId: v.id("profiles"), active: v.boolean(), activeUntil: v.optional(v.number()),
  }).index("by_profile", ["profileId"]),

  // Bounded to 100 validated foods by syncDay, separate from dashboard totals.
  sharedFoodDays: defineTable({
    ownerProfileId: v.id("profiles"),
    day: v.string(),
    foods: v.array(foodInput),
    updatedAt: v.number(),
  })
    .index("by_owner_day", ["ownerProfileId", "day"])
    .index("by_day", ["day"]),

  profiles: defineTable({
    profileKey: v.string(),
    displayName: v.string(),
    secretHash: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
    deletedAt: v.optional(v.number()),
  }).index("by_profile_key", ["profileKey"]),

  profileQuotas: defineTable({
    profileId: v.id("profiles"),
    dayKey: v.string(),
    invitesCreated: v.number(),
    snapshotUpserts: v.number(),
    displayNameUpdates: v.number(),
  }).index("by_profile_id_and_day_key", ["profileId", "dayKey"]),

  dailySnapshots: defineTable({
    ownerProfileId: v.id("profiles"),
    day: v.string(),
    timeZoneId: v.string(),
    calories: v.number(),
    protein: v.number(),
    fat: v.number(),
    carbs: v.number(),
    entryCount: v.number(),
    calorieGoal: v.optional(v.number()),
    proteinGoal: v.optional(v.number()),
    carbsGoal: v.optional(v.number()),
    fatGoal: v.optional(v.number()),
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
    .index("by_profile_b", ["profileBId"])
    .index("by_profile_a_removed", ["profileAId", "removedAt"])
    .index("by_profile_b_removed", ["profileBId", "removedAt"]),

  shareGrantIntervals: defineTable({
    relationshipId: v.id("shareRelationships"),
    fromProfileId: v.id("profiles"),
    toProfileId: v.id("profiles"),
    scope: v.object({ macros: v.boolean(), foods: v.optional(v.boolean()) }),
    startDay: v.string(),
    endDay: v.optional(v.string()),
    startedAt: v.number(),
    endedAt: v.optional(v.number()),
  })
    .index("by_from_to", ["fromProfileId", "toProfileId"])
    .index("by_from_to_ended", ["fromProfileId", "toProfileId", "endedAt"])
    .index("by_to_from", ["toProfileId", "fromProfileId"])
    .index("by_relationship", ["relationshipId"]),
});
