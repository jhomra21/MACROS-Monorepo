import { ConvexError } from "convex/values";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";

export type ProfileQuotaCounter = "invitesCreated" | "snapshotUpserts" | "displayNameUpdates";

const QUOTA_LIMITS: Record<ProfileQuotaCounter, number> = {
  invitesCreated: 20,
  snapshotUpserts: 200,
  displayNameUpdates: 20,
};

export async function consumeProfileQuota(
  ctx: MutationCtx,
  profileId: Id<"profiles">,
  counter: ProfileQuotaCounter,
): Promise<void> {
  const dayKey = new Date().toISOString().slice(0, 10);

  const quota = await ctx.db
    .query("profileQuotas")
    .withIndex("by_profile_id_and_day_key", (q) => q.eq("profileId", profileId).eq("dayKey", dayKey))
    .unique();

  const currentCount = quota?.[counter] ?? 0;

  if (currentCount >= QUOTA_LIMITS[counter]) {
    throw new ConvexError({ code: "QUOTA_EXCEEDED" });
  }

  if (quota == null) {
    await ctx.db.insert("profileQuotas", {
      profileId,
      dayKey,
      invitesCreated: counter === "invitesCreated" ? 1 : 0,
      snapshotUpserts: counter === "snapshotUpserts" ? 1 : 0,
      displayNameUpdates: counter === "displayNameUpdates" ? 1 : 0,
    });
  } else {
    await ctx.db.patch(quota._id, { [counter]: currentCount + 1 });
  }
}
