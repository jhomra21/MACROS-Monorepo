import type { Id } from "./_generated/dataModel";
import type { QueryCtx } from "./_generated/server";

export const PRO_PRODUCTS = new Set(["macros.pro.monthly", "macros.pro.yearly", "macros.pro.lifetime"]);

export function connectionActive(requirePro: boolean, aActive: boolean, bActive: boolean): boolean {
  return !requirePro || aActive || bActive;
}

export async function requireProEnabled(ctx: QueryCtx): Promise<boolean> {
  return (await ctx.db.query("settings").unique())?.sharingRequirePro ?? false;
}

export async function hasPro(ctx: QueryCtx, profileId: Id<"profiles">): Promise<boolean> {
  return (await ctx.db.query("proStatus").withIndex("by_profile", q => q.eq("profileId", profileId)).unique())?.active ?? false;
}

export async function activeConnection(ctx: QueryCtx, a: Id<"profiles">, b: Id<"profiles">): Promise<boolean> {
  if (!await requireProEnabled(ctx)) return true;

  return connectionActive(true, await hasPro(ctx, a), await hasPro(ctx, b));
}
