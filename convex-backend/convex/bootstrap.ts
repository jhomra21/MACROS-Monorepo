import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { normalizeDisplayName } from "./sharingModel";

export const registerOrVerifyProfile = internalMutation({
  args: {
    profileKey: v.string(),
    secretHash: v.string(),
    displayName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("profiles")
      .withIndex("by_profile_key", (q) => q.eq("profileKey", args.profileKey))
      .unique();

    if (existing != null) {
      if (existing.deletedAt != null || existing.secretHash !== args.secretHash) {
        throw new Error("Profile credentials are invalid.");
      }
      return {
        profileKey: existing.profileKey,
        displayName: existing.displayName,
        deleted: false,
      };
    }

    if (args.displayName == null) {
      throw new Error("Display name is required for first sharing setup.");
    }

    const displayName = normalizeDisplayName(args.displayName);
    await ctx.db.insert("profiles", {
      profileKey: args.profileKey,
      secretHash: args.secretHash,
      displayName,
      createdAt: now,
      updatedAt: now,
    });

    return {
      profileKey: args.profileKey,
      displayName,
      deleted: false,
    };
  },
});
