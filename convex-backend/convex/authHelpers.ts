import type { QueryCtx } from "./_generated/server";

export async function requireCurrentProfile(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity == null) {
    throw new Error("Authentication required.");
  }

  const profile = await ctx.db
    .query("profiles")
    .withIndex("by_profile_key", (q) => q.eq("profileKey", identity.subject))
    .unique();

  if (profile == null || profile.deletedAt != null) {
    throw new Error("Sharing profile is unavailable.");
  }

  return profile;
}
