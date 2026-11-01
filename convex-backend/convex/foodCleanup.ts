import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";

export const deleteOwnerBeforeDay = internalMutation({
  args: { ownerProfileId: v.id("profiles"), day: v.string() }, returns: v.null(),
  handler: async (ctx, args) => {
    const rows = await ctx.db.query("sharedFoodDays").withIndex("by_owner_day",
      q => q.eq("ownerProfileId", args.ownerProfileId).lt("day", args.day)).take(100);

    await Promise.all(rows.map(row => ctx.db.delete(row._id)));

    if (rows.length === 100) await ctx.scheduler.runAfter(0, internal.foodCleanup.deleteOwnerBeforeDay, args);

    return null;
  },
});

export const sweep = internalMutation({
  args: {}, returns: v.null(),
  handler: async ctx => {
    const cutoff = new Date().toISOString().slice(0, 10);
    const rows = await ctx.db.query("sharedFoodDays").withIndex("by_day", q => q.lt("day", cutoff)).take(100);
    await Promise.all(rows.map(row => ctx.db.delete(row._id)));

    if (rows.length === 100) await ctx.scheduler.runAfter(0, internal.foodCleanup.sweep, {});

    return null;
  },
});
