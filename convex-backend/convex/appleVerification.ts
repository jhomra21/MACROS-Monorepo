"use node";

import { v } from "convex/values";
import { internalAction } from "./_generated/server";
import { AppleVerifier } from "./_lib/appleVerifier.node";
import { notificationRecord } from "./_lib/purchasePolicy";
import { entitlementFields } from "./sharingValidators";

export const verifyNotification = internalAction({
  args: { signedPayload: v.string() },
  returns: v.union(v.object(entitlementFields), v.null()),
  handler: async (_ctx, args) => {
    const verifier = new AppleVerifier();
    const notification = await verifier.notification(args.signedPayload);
    const data = notification.data;

    if (!data?.signedTransactionInfo) {
      // Apple sends TEST notifications without transaction information.
      if (notification.notificationType === "TEST") return null;
      throw new Error("Missing signed transaction.");
    }

    const transaction = await verifier.transaction(data.signedTransactionInfo);
    const renewal = data.signedRenewalInfo ? await verifier.renewal(data.signedRenewalInfo) : undefined;

    return notificationRecord(notification, transaction, renewal);
  },
});
