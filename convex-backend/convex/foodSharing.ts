import type { Infer } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { activeConnection } from "./proModel";
import { foodInput } from "./sharingValidators";
import { assertCurrentDayKey, assertValidSnapshot, type SnapshotInput } from "./sharingModel";
import { consumeProfileQuota } from "./quotas";
import { internal } from "./_generated/api";

export type FoodInput = Infer<typeof foodInput>;

export async function openGrantBetween(ctx: QueryCtx, from: Id<"profiles">, to: Id<"profiles">) {
  return await ctx.db.query("shareGrantIntervals").withIndex("by_from_to_ended",
    q => q.eq("fromProfileId", from).eq("toProfileId", to).eq("endedAt", undefined)).first();
}

export async function hasActiveFoodGrant(ctx: QueryCtx, owner: Id<"profiles">, day: string) {
  // Owner-prefix iteration avoids reading grant history into memory. Stop at the
  // first eligible recipient. The exact pair's active lookup uses the ended index.
  for await (const relationship of ctx.db.query("shareRelationships").withIndex("by_profile_a", q => q.eq("profileAId", owner))) {
    if (await relationshipAllowsFoods(ctx, relationship, owner, day)) return true;
  }

  for await (const relationship of ctx.db.query("shareRelationships").withIndex("by_profile_b", q => q.eq("profileBId", owner))) {
    if (await relationshipAllowsFoods(ctx, relationship, owner, day)) return true;
  }

  return false;
}

async function relationshipAllowsFoods(ctx: QueryCtx, relationship: Doc<"shareRelationships">, owner: Id<"profiles">, day: string) {
  if (relationship.removedAt != null) return false;
  const otherId = relationship.profileAId === owner ? relationship.profileBId : relationship.profileAId;
  const other = await ctx.db.get(otherId);

  if (!other || other.deletedAt != null) return false;
  const grant = await openGrantBetween(ctx, owner, otherId);

  return !!grant?.scope.macros && grant.scope.foods === true && grant.startDay <= day &&
    await activeConnection(ctx, owner, otherId);
}

export async function deleteDayFoods(ctx: MutationCtx, owner: Id<"profiles">, day: string) {
  const rows = await ctx.db.query("sharedFoodEntries")
    .withIndex("by_owner_day_sort", q => q.eq("ownerProfileId", owner).eq("day", day)).take(100);

  await Promise.all(rows.map(row => ctx.db.delete(row._id)));
}

export async function clearFoodsWithoutRecipients(ctx: MutationCtx, owner: Id<"profiles">, day: string) {
  if (!await hasActiveFoodGrant(ctx, owner, day)) await deleteDayFoods(ctx, owner, day);
}

function validateFoods(foods: FoodInput[]) {
  if (foods.length > 100) throw new Error("At most 100 foods may be shared per day.");
  const ids = new Set<string>();

  for (const food of foods) {
    if (!food.localEntryId || food.localEntryId.length > 128 || ids.has(food.localEntryId)) throw new Error("Invalid or duplicate localEntryId.");
    ids.add(food.localEntryId);

    if (!food.name.trim() || food.name.length > 80 || food.quantityText.length > 40) throw new Error("Food text exceeds bounds.");

    if (!Number.isSafeInteger(food.sortIndex) || food.sortIndex < 0 || food.sortIndex > 10_000) throw new Error("Invalid sortIndex.");

    for (const value of [food.calories, food.protein, food.carbs, food.fat]) {
      if (!Number.isFinite(value) || value < 0 || value > 50_000) throw new Error("Invalid food nutrition.");
    }
  }
}

export function foodDTO(row: FoodInput): FoodInput {
  return {
    localEntryId: row.localEntryId, sortIndex: row.sortIndex, name: row.name, quantityText: row.quantityText,
    calories: row.calories, protein: row.protein, carbs: row.carbs, fat: row.fat,
  };
}

async function diffFoods(ctx: MutationCtx, owner: Id<"profiles">, day: string, foods: FoodInput[], now: number) {
  const rows = await ctx.db.query("sharedFoodEntries")
    .withIndex("by_owner_day_sort", q => q.eq("ownerProfileId", owner).eq("day", day)).take(100);

  const existing = new Map(rows.map(row => [row.localEntryId, row]));

  for (const food of foods) {
    const row = existing.get(food.localEntryId);
    existing.delete(food.localEntryId);

    if (!row) await ctx.db.insert("sharedFoodEntries", { ...food, ownerProfileId: owner, day, updatedAt: now });
    else if (JSON.stringify(foodDTO(row)) !== JSON.stringify(foodDTO(food))) await ctx.db.patch(row._id, { ...food, updatedAt: now });
  }

  await Promise.all([...existing.values()].map(row => ctx.db.delete(row._id)));
}

export async function syncDay(ctx: MutationCtx, owner: Id<"profiles">, snapshot: SnapshotInput, foods?: FoodInput[]) {
  assertValidSnapshot(snapshot);
  assertCurrentDayKey(snapshot.day);

  if (foods) validateFoods(foods);
  await consumeProfileQuota(ctx, owner, "snapshotUpserts");
  const now = Date.now();

  const existing = await ctx.db.query("dailySnapshots")
    .withIndex("by_owner_day", q => q.eq("ownerProfileId", owner).eq("day", snapshot.day)).unique();

  const fields = { ...snapshot, ownerProfileId: owner, updatedAt: now };
  const snapshotId = existing?._id ?? await ctx.db.insert("dailySnapshots", fields);

  if (existing) await ctx.db.patch(existing._id, fields);

  if (!existing) {
    await ctx.scheduler.runAfter(0, internal.foodCleanup.deleteOwnerBeforeDay, { ownerProfileId: owner, day: snapshot.day });

    // The first bounded batch is immediate; the job drains any legacy leftovers.
    const old = await ctx.db.query("sharedFoodEntries")
      .withIndex("by_owner_day_sort", q => q.eq("ownerProfileId", owner).lt("day", snapshot.day)).take(100);

    await Promise.all(old.map(row => ctx.db.delete(row._id)));
  }

  if (await hasActiveFoodGrant(ctx, owner, snapshot.day)) {
    if (foods !== undefined) await diffFoods(ctx, owner, snapshot.day, foods, now);
  } else await deleteDayFoods(ctx, owner, snapshot.day);

  return { snapshotId };
}
