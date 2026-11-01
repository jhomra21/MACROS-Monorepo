import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { requireCurrentProfile } from "./authHelpers";
import { entitlementFields } from "./sharingValidators";

export const currentProfile = internalQuery({
  args: {}, returns: v.id("profiles"),
  handler: async ctx => (await requireCurrentProfile(ctx))._id,
});

export const storePurchase = internalMutation({
  args: { profileId: v.id("profiles"), transactionSignedAt: v.number(), ...entitlementFields },
  returns: v.null(),
  handler: async (ctx, args) => {
    // The profile can be tombstoned while the Node action verifies a purchase.
    const profile = await ctx.db.get(args.profileId);

    if (profile == null || profile.deletedAt != null) throw new Error("Sharing profile is unavailable.");

    const rows = await ctx.db.query("entitlements")
      .withIndex("by_original_transaction", q => q.eq("originalTransactionId", args.originalTransactionId)).take(6);

    const existing = rows.find(row => row.profileId === args.profileId);

    if (rows.some(row => row.environment !== args.environment)) throw new Error("Transaction environment mismatch.");

    if (!existing && rows.length >= 5) throw new Error("A purchase can be used by at most 5 profiles.");

    const latest = [...rows].sort((a, b) => b.verifiedAt - a.verifiedAt)[0];

    // The latest verified state belongs to the purchase, not the submitting
    // profile. A stale JWS must not revive a refund by attaching another profile.
    const keepLatest = latest && (latest.verifiedAt >= args.verifiedAt ||
      (latest.revokedAt != null && args.transactionSignedAt <= latest.verifiedAt));

    const state = keepLatest ? {
      productId: latest.productId, originalTransactionId: latest.originalTransactionId,
      environment: latest.environment, expiresAt: latest.expiresAt,
      revokedAt: latest.revokedAt, verifiedAt: latest.verifiedAt,
    } : {
      productId: args.productId, originalTransactionId: args.originalTransactionId,
      environment: args.environment, expiresAt: args.expiresAt,
      revokedAt: args.revokedAt, verifiedAt: args.verifiedAt,
    };

    for (const row of rows) {
      if (state.verifiedAt > row.verifiedAt) await ctx.db.patch(row._id, state);
    }

    if (!existing) await ctx.db.insert("entitlements", { profileId: args.profileId, ...state });

    return null;
  },
});

export const applyNotification = internalMutation({
  args: entitlementFields,
  returns: v.null(),
  handler: async (ctx, args) => {
    const rows = await ctx.db.query("entitlements")
      .withIndex("by_original_transaction", q => q.eq("originalTransactionId", args.originalTransactionId)).take(5);

    for (const row of rows) {
      if (row.environment === args.environment && args.verifiedAt > row.verifiedAt) {
        await ctx.db.patch(row._id, { ...args, revokedAt: args.revokedAt, expiresAt: args.expiresAt });
      }
    }

    return null;
  },
});
