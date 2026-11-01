"use node";

import { v } from "convex/values";
import { action } from "./_generated/server";
import { internal } from "./_generated/api";
import { AppleVerifier } from "./_lib/appleVerifier.node";
import { purchaseRecord } from "./_lib/purchasePolicy";

export const submitPurchase = action({
  args: { signedTransaction: v.string(), signedRenewalInfo: v.optional(v.string()) },
  returns: v.object({ ok: v.boolean() }),
  handler: async (ctx, args): Promise<{ ok: boolean }> => {
    const profileId = await ctx.runQuery(internal.entitlementRecords.currentProfile, {});
    const verifier = new AppleVerifier();
    const transaction = await verifier.transaction(args.signedTransaction);
    const renewal = args.signedRenewalInfo ? await verifier.renewal(args.signedRenewalInfo) : undefined;
    const record = purchaseRecord(transaction, renewal);
    const result = await ctx.runMutation(internal.entitlementRecords.storePurchase, { profileId, ...record });

    if (result === "revoked") throw new Error("Purchase transaction is revoked.");

    if (result === "profileLimit") throw new Error("A purchase can be used by at most 5 profiles.");

    return { ok: true };
  },
});
