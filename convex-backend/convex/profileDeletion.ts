import { v } from "convex/values";
import { internalMutation, type MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";

async function nextBatch(ctx: MutationCtx, id: Id<"profiles">, stage: number) {
  // One indexed batch per invocation, never 100 from each table at once.
  switch (stage) {
    case 0: return await ctx.db.query("shareInvites").withIndex("by_owner_status", q => q.eq("ownerProfileId", id)).take(100);
    case 1: return await ctx.db.query("shareInvites").withIndex("by_accepted_by", q => q.eq("acceptedByProfileId", id)).take(100);
    case 2: return await ctx.db.query("dailySnapshots").withIndex("by_owner_day", q => q.eq("ownerProfileId", id)).take(100);
    case 3: return await ctx.db.query("sharedFoodDays").withIndex("by_owner_day", q => q.eq("ownerProfileId", id)).take(100);
    case 4: return await ctx.db.query("shareGrantIntervals").withIndex("by_from_to", q => q.eq("fromProfileId", id)).take(100);
    case 5: return await ctx.db.query("shareGrantIntervals").withIndex("by_to_from", q => q.eq("toProfileId", id)).take(100);
    case 6: return await ctx.db.query("shareRelationships").withIndex("by_profile_a", q => q.eq("profileAId", id)).take(100);
    case 7: return await ctx.db.query("shareRelationships").withIndex("by_profile_b", q => q.eq("profileBId", id)).take(100);
    case 8: return await ctx.db.query("profileQuotas").withIndex("by_profile_id_and_day_key", q => q.eq("profileId", id)).take(100);
    case 9: return await ctx.db.query("purchaseLinks").withIndex("by_profile", q => q.eq("profileId", id)).take(100);
    case 10: return await ctx.db.query("proStatus").withIndex("by_profile", q => q.eq("profileId", id)).take(100);
    default: return [];
  }
}

export const deleteBatch = internalMutation({
  args: { profileId: v.id("profiles"), stage: v.number() }, returns: v.null(),
  handler: async (ctx, args) => {
    const profile = await ctx.db.get(args.profileId);

    if (profile?.deletedAt == null) throw new Error("Only tombstoned profiles may be cleaned up.");
    const rows = await nextBatch(ctx, args.profileId, args.stage);
    await Promise.all(rows.map(row => ctx.db.delete(row._id)));
    const stage = rows.length === 100 ? args.stage : args.stage + 1;

    if (stage <= 10) await ctx.scheduler.runAfter(0, internal.profileDeletion.deleteBatch, { profileId: args.profileId, stage });

    return null;
  },
});
