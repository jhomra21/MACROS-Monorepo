import type { Doc, Id } from "./_generated/dataModel";
import type { QueryCtx } from "./_generated/server";

export const PRO_PRODUCTS = new Set(["macros.pro.monthly", "macros.pro.yearly", "macros.pro.lifetime"]);

// Pure policy: callers provide the indexed entitlement rows and the same clock.
export function hasPro(profileId: Id<"profiles">, now: number, entitlements: readonly Doc<"entitlements">[]): boolean {
  return entitlements.some(row => row.profileId === profileId && PRO_PRODUCTS.has(row.productId) &&
    row.revokedAt == null && (row.productId === "macros.pro.lifetime" || (row.expiresAt ?? 0) > now));
}

export function connectionActive(
  a: Id<"profiles">, b: Id<"profiles">, now: number,
  sharingRequirePro: boolean, entitlements: readonly Doc<"entitlements">[],
): boolean {
  return !sharingRequirePro || hasPro(a, now, entitlements) || hasPro(b, now, entitlements);
}

export async function requireProEnabled(ctx: QueryCtx): Promise<boolean> {
  return (await ctx.db.query("settings").unique())?.sharingRequirePro ?? false;
}

export async function proEntitlements(ctx: QueryCtx, profileId: Id<"profiles">, now: number): Promise<Doc<"entitlements">[]> {
  // A single witness is sufficient; don't materialize expired purchase history.
  for await (const row of ctx.db.query("entitlements").withIndex("by_profile", q => q.eq("profileId", profileId))) {
    if (hasPro(profileId, now, [row])) return [row];
  }

  return [];
}

export async function activeConnection(ctx: QueryCtx, a: Id<"profiles">, b: Id<"profiles">, now = Date.now()) {
  const requirePro = await requireProEnabled(ctx);

  if (!requirePro) return true;
  const [aRows, bRows] = await Promise.all([proEntitlements(ctx, a, now), proEntitlements(ctx, b, now)]);

  return connectionActive(a, b, now, requirePro, [...aRows, ...bRows]);
}
