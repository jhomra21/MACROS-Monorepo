import type { JWSTransactionDecodedPayload, JWSRenewalInfoDecodedPayload, ResponseBodyV2DecodedPayload } from "@apple/app-store-server-library";
import { PRO_PRODUCTS } from "../proModel";
import type { Infer } from "convex/values";
import { entitlementValidator } from "../sharingValidators";

export function purchaseRecord(transaction: JWSTransactionDecodedPayload, renewal?: JWSRenewalInfoDecodedPayload): Infer<typeof entitlementValidator> {
  const { productId, originalTransactionId, environment, signedDate } = transaction;

  if (!productId || !PRO_PRODUCTS.has(productId)) throw new Error("Unsupported Pro product.");

  if (!originalTransactionId || originalTransactionId.length > 128) throw new Error("Invalid transaction.");

  if (environment !== "Production" && environment !== "Sandbox") throw new Error("Unsupported Apple environment.");

  if (!Number.isFinite(signedDate)) throw new Error("Missing transaction signedDate.");

  if (transaction.bundleId !== "juan-test.cal-macro-tracker") throw new Error("Invalid bundle.");

  if (renewal) assertMatchingRenewal(transaction, renewal);
  const lifetime = productId === "macros.pro.lifetime";

  if (!lifetime && !Number.isFinite(transaction.expiresDate)) throw new Error("Missing expiry.");
  const expiresAt = lifetime ? undefined : Math.max(transaction.expiresDate ?? 0, renewal?.gracePeriodExpiresDate ?? 0);
  // Use Apple's signed clock, not receipt time, to prevent old purchases reviving refunds.
  const verifiedAt = Math.max(signedDate ?? 0, renewal?.signedDate ?? 0);

  return {
    productId, originalTransactionId, environment,
    expiresAt, revokedAt: transaction.revocationDate, verifiedAt,
  };
}

function assertMatchingRenewal(transaction: JWSTransactionDecodedPayload, renewal: JWSRenewalInfoDecodedPayload) {
  if (renewal.originalTransactionId !== transaction.originalTransactionId ||
    renewal.environment !== transaction.environment || renewal.productId !== transaction.productId) {
    throw new Error("Renewal transaction mismatch.");
  }
}

export function notificationRecord(
  notification: ResponseBodyV2DecodedPayload,
  transaction: JWSTransactionDecodedPayload,
  renewal?: JWSRenewalInfoDecodedPayload,
): Infer<typeof entitlementValidator> | null {
  if (transaction.environment !== notification.data?.environment || !Number.isFinite(notification.signedDate)) {
    throw new Error("Notification context mismatch.");
  }

  if (!PRO_PRODUCTS.has(transaction.productId ?? "")) return null;
  const record = purchaseRecord(transaction, renewal);
  const verifiedAt = notification.signedDate ?? 0;

  switch (notification.notificationType) {
    case "EXPIRED":
      return { ...record, verifiedAt, expiresAt: Math.min(transaction.expiresDate ?? verifiedAt, verifiedAt) };
    case "REFUND":
    case "REVOKE":
      return { ...record, verifiedAt, revokedAt: transaction.revocationDate ?? verifiedAt };
    case "DID_FAIL_TO_RENEW":
      if (notification.subtype !== "GRACE_PERIOD") return null;

      if (!Number.isFinite(renewal?.gracePeriodExpiresDate)) throw new Error("Missing grace expiry.");

      return { ...record, verifiedAt, expiresAt: renewal?.gracePeriodExpiresDate };
    case "DID_RENEW":
    case "SUBSCRIBED":
      return { ...record, verifiedAt };
    default:
      return null;
  }
}
