import { v, type Infer } from "convex/values";
import { internalMutation, internalQuery, type MutationCtx } from "./_generated/server";
import { requireCurrentProfile } from "./authHelpers";
import { purchaseFields, purchaseValidator } from "./sharingValidators";
import { recomputeProfile } from "./proStatus";

export const currentProfile = internalQuery({
  args: {}, returns: v.id("profiles"),
  handler: async ctx => (await requireCurrentProfile(ctx))._id,
});

async function applyPurchase(ctx: MutationCtx, { transaction, renewal }: Infer<typeof purchaseValidator>) {
  const existing = await ctx.db.query("appleTransactions")
    .withIndex("by_transaction", q => q.eq("transactionId", transaction.transactionId)).unique();

  const purchase = await ctx.db.query("appleTransactions")
    .withIndex("by_original", q => q.eq("originalTransactionId", transaction.originalTransactionId)).first();

  if ((existing && (existing.originalTransactionId !== transaction.originalTransactionId ||
    existing.productId !== transaction.productId)) || (purchase && purchase.environment !== transaction.environment) ||
    (existing && existing.environment !== transaction.environment)) {
    throw new Error("Transaction identity or environment mismatch.");
  }

  const useIncoming = !existing || transaction.transactionSignedDate > existing.transactionSignedDate;

  if (!existing) await ctx.db.insert("appleTransactions", transaction);
  else if (useIncoming) await ctx.db.replace(existing._id, transaction);

  if (renewal) {
    const previous = await ctx.db.query("appleRenewals")
      .withIndex("by_original", q => q.eq("originalTransactionId", transaction.originalTransactionId)).unique();

    const state = { originalTransactionId: transaction.originalTransactionId, ...renewal };

    if (!previous) await ctx.db.insert("appleRenewals", state);
    else if (renewal.renewalSignedDate > previous.renewalSignedDate) await ctx.db.replace(previous._id, state);
  }

  return useIncoming ? transaction : existing;
}

async function recomputeLinkedProfiles(ctx: MutationCtx, originalTransactionId: string) {
  const links = await ctx.db.query("purchaseLinks")
    .withIndex("by_original", q => q.eq("originalTransactionId", originalTransactionId)).take(5);

  for (const link of links) await recomputeProfile(ctx, link.profileId);
}

export const storePurchase = internalMutation({
  args: { profileId: v.id("profiles"), ...purchaseFields },
  returns: v.union(v.literal("accepted"), v.literal("revoked"), v.literal("profileLimit")),
  handler: async (ctx, { profileId, ...record }) => {
    // The profile can be tombstoned while the Node action verifies a purchase.
    const profile = await ctx.db.get(profileId);

    if (!profile || profile.deletedAt != null) throw new Error("Sharing profile is unavailable.");

    const transaction = await applyPurchase(ctx, record);

    const links = await ctx.db.query("purchaseLinks")
      .withIndex("by_original", q => q.eq("originalTransactionId", record.transaction.originalTransactionId)).take(5);

    const linked = links.some(link => link.profileId === profileId);

    const result = transaction.revokedAt != null ? "revoked"
      : !linked && links.length >= 5 ? "profileLimit" : "accepted";

    if (result === "accepted" && !linked) await ctx.db.insert("purchaseLinks", {
      originalTransactionId: transaction.originalTransactionId, profileId,
    });
    await recomputeLinkedProfiles(ctx, transaction.originalTransactionId);

    // Reject in the action, not here: verified state and linked profiles' Pro
    // updates must commit even when this profile cannot attach to the purchase.
    return result;
  },
});

export const applyNotification = internalMutation({
  args: purchaseFields, returns: v.null(),
  handler: async (ctx, record) => {
    await applyPurchase(ctx, record);
    await recomputeLinkedProfiles(ctx, record.transaction.originalTransactionId);

    return null;
  },
});
