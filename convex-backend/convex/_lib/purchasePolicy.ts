import type { JWSTransactionDecodedPayload, JWSRenewalInfoDecodedPayload, ResponseBodyV2DecodedPayload } from "@apple/app-store-server-library";
import type { Infer } from "convex/values";
import { PRO_PRODUCTS } from "../proModel";
import { purchaseValidator } from "../sharingValidators";

export function purchaseRecord(
  transaction: JWSTransactionDecodedPayload, renewal?: JWSRenewalInfoDecodedPayload,
): Infer<typeof purchaseValidator> {
  const { transactionId, productId, originalTransactionId, environment, signedDate } = transaction;

  if (!productId || !PRO_PRODUCTS.has(productId)) throw new Error("Unsupported Pro product.");

  if (!transactionId || transactionId.length > 128 || !originalTransactionId || originalTransactionId.length > 128) {
    throw new Error("Invalid transaction.");
  }

  if (environment !== "Production" && environment !== "Sandbox") throw new Error("Unsupported Apple environment.");

  if (!Number.isFinite(signedDate)) throw new Error("Missing transaction signedDate.");

  if (transaction.bundleId !== "juan-test.cal-macro-tracker") throw new Error("Invalid bundle.");

  const lifetime = productId === "macros.pro.lifetime";

  if (!lifetime && !Number.isFinite(transaction.expiresDate)) throw new Error("Missing expiry.");

  if (renewal) {
    if (renewal.originalTransactionId !== originalTransactionId || renewal.environment !== environment ||
      renewal.productId !== productId) throw new Error("Renewal transaction mismatch.");

    if (!Number.isFinite(renewal.signedDate)) throw new Error("Missing renewal signedDate.");
  }

  return {
    transaction: {
      transactionId, productId, originalTransactionId, environment,
      expiresAt: lifetime ? undefined : transaction.expiresDate,
      revokedAt: transaction.revocationDate, transactionSignedDate: signedDate!,
    },
    renewal: renewal && {
      gracePeriodExpiresAt: renewal.gracePeriodExpiresDate, autoRenewStatus: renewal.autoRenewStatus,
      renewalSignedDate: renewal.signedDate!,
    },
  };
}

export function notificationRecord(
  notification: ResponseBodyV2DecodedPayload,
  transaction: JWSTransactionDecodedPayload,
  renewal?: JWSRenewalInfoDecodedPayload,
): Infer<typeof purchaseValidator> | null {
  if (transaction.environment !== notification.data?.environment || !Number.isFinite(notification.signedDate)) {
    throw new Error("Notification context mismatch.");
  }

  if (!PRO_PRODUCTS.has(transaction.productId ?? "")) return null;
  const record = purchaseRecord(transaction, renewal);

  // Each signed object owns its watermark. The outer notification clock must
  // never advance transaction coverage or renewal state.
  switch (notification.notificationType) {
    case "REFUND":
    case "REVOKE":
      record.transaction.revokedAt = transaction.revocationDate ?? notification.signedDate;
      break;
    case "REFUND_REVERSED":
      record.transaction.revokedAt = undefined;
      break;
    case "DID_FAIL_TO_RENEW":
      if (notification.subtype === "GRACE_PERIOD" && !Number.isFinite(renewal?.gracePeriodExpiresDate)) {
        throw new Error("Missing grace expiry.");
      }

      break;
  }

  // Even notifications that don't grant access can carry newer signed state.
  return record;
}
