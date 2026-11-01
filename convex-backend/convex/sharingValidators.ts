import { v } from "convex/values";

export const transactionFields = {
  transactionId: v.string(), productId: v.string(), originalTransactionId: v.string(),
  expiresAt: v.optional(v.number()), revokedAt: v.optional(v.number()),
  environment: v.union(v.literal("Production"), v.literal("Sandbox")), transactionSignedDate: v.number(),
};

export const renewalFields = {
  gracePeriodExpiresAt: v.optional(v.number()), autoRenewStatus: v.optional(v.number()), renewalSignedDate: v.number(),
};

export const purchaseFields = {
  transaction: v.object(transactionFields), renewal: v.optional(v.object(renewalFields)),
};

export const purchaseValidator = v.object(purchaseFields);

export const okResult = v.object({ ok: v.boolean() });

export const snapshotFields = {
  day: v.string(), timeZoneId: v.string(), calories: v.number(),
  protein: v.number(), fat: v.number(), carbs: v.number(), entryCount: v.number(),
  calorieGoal: v.optional(v.number()), proteinGoal: v.optional(v.number()),
  carbsGoal: v.optional(v.number()), fatGoal: v.optional(v.number()),
};

export const snapshotInput = v.object(snapshotFields);

export const snapshotDTO = v.object({ ...snapshotFields, updatedAt: v.number() });

export const foodInput = v.object({
  localEntryId: v.string(), sortIndex: v.number(), name: v.string(), quantityText: v.string(),
  calories: v.number(), protein: v.number(), carbs: v.number(), fat: v.number(),
});

export const scopeName = v.union(v.literal("off"), v.literal("macros"), v.literal("macrosAndFoods"));

export const snapshotResult = v.object({ snapshotId: v.id("dailySnapshots") });

export const dashboardResult = v.object({
  people: v.array(v.object({
    relationshipId: v.id("shareRelationships"), profileId: v.id("profiles"), displayName: v.string(),
    incomingActive: v.boolean(), outgoingActive: v.boolean(), scope: v.object({ macros: v.boolean() }),
    snapshot: v.union(snapshotDTO, v.null()), foodsShared: v.boolean(),
    outgoingScope: scopeName, connectionPaused: v.boolean(),
  })),
});

export const personDayResult = v.object({
  visibility: v.union(v.literal("shared"), v.literal("notShared"), v.literal("paused")),
  snapshot: v.union(snapshotDTO, v.null()), foods: v.array(foodInput),
});
