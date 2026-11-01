import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, type MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";

async function purchaseCoverage(ctx: MutationCtx, originalTransactionId: string) {
  let lifetime = false;
  let coverageEnd = 0;
  let latestSubscription: Doc<"appleTransactions"> | undefined;

  for await (const transaction of ctx.db.query("appleTransactions")
    .withIndex("by_original", q => q.eq("originalTransactionId", originalTransactionId))) {
    if (transaction.expiresAt != null && (!latestSubscription ||
      transaction.expiresAt > (latestSubscription.expiresAt ?? 0))) latestSubscription = transaction;

    if (transaction.revokedAt != null) continue;

    if (transaction.expiresAt == null) lifetime = true;
    else coverageEnd = Math.max(coverageEnd, transaction.expiresAt);
  }

  // Grace covers the latest subscription period. An older unrevoked period
  // cannot lend its grace to a refunded latest period or a lifetime purchase.
  if (latestSubscription && latestSubscription.revokedAt == null) {
    const renewal = await ctx.db.query("appleRenewals")
      .withIndex("by_original", q => q.eq("originalTransactionId", originalTransactionId)).unique();

    coverageEnd = Math.max(coverageEnd, renewal?.gracePeriodExpiresAt ?? 0);
  }

  return { lifetime, coverageEnd };
}

export async function recomputeProfile(ctx: MutationCtx, profileId: Id<"profiles">): Promise<void> {
  const profile = await ctx.db.get(profileId);
  const existing = await ctx.db.query("proStatus").withIndex("by_profile", q => q.eq("profileId", profileId)).unique();

  // A pending expiry job must not recreate derived data after profile deletion.
  if (!profile || profile.deletedAt != null) {
    if (existing) await ctx.db.delete(existing._id);

    return;
  }

  const now = Date.now();
  let lifetime = false;
  let coverageEnd = 0;

  for await (const link of ctx.db.query("purchaseLinks").withIndex("by_profile", q => q.eq("profileId", profileId))) {
    const coverage = await purchaseCoverage(ctx, link.originalTransactionId);
    lifetime ||= coverage.lifetime;
    coverageEnd = Math.max(coverageEnd, coverage.coverageEnd);
  }

  const active = lifetime || coverageEnd > now;
  const activeUntil = active && !lifetime ? coverageEnd : undefined;

  if (existing?.active === active && existing.activeUntil === activeUntil) return;

  if (existing) await ctx.db.patch(existing._id, { active, activeUntil });
  else await ctx.db.insert("proStatus", { profileId, active, activeUntil });

  // An older job simply recomputes current coverage after a renewal. Scheduling
  // only when the derived status changes prevents duplicate jobs on JWS retries.
  if (activeUntil != null) await ctx.scheduler.runAt(activeUntil, internal.proStatus.recompute, { profileId });
}

export const recompute = internalMutation({
  args: { profileId: v.id("profiles") }, returns: v.null(),
  handler: async (ctx, { profileId }) => {
    await recomputeProfile(ctx, profileId);

    return null;
  },
});
