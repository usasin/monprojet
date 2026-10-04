import {createHash} from "node:crypto";
import {Environment, JWSTransactionDecodedPayload, Type} from "@apple/app-store-server-library";

export const appleBundleId = "com.ainego.aiProspectGps";
export const appleAppId = 6747984215;
export const appleProducts = new Set(["premium_monthly", "premium_yearly"]);

// Stable opaque UUID; Firebase identifiers and emails are never sent to Apple.
export function appleAccountToken(uid: string): string {
  const bytes = createHash("sha256").update(`prospecto.apple.account:${uid}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function appleSubscriptionKey(transaction: JWSTransactionDecodedPayload): string {
  if (![Environment.PRODUCTION, Environment.SANDBOX].includes(transaction.environment as Environment) ||
      !/^\d{1,40}$/.test(transaction.originalTransactionId ?? "")) {
    throw new Error("Identifiant de transaction Apple invalide.");
  }
  return `${transaction.environment}_${transaction.originalTransactionId}`;
}

// Input must already have passed SignedDataVerifier; decoding a JWS alone is insufficient.
export function validateApplePurchase(
  transaction: JWSTransactionDecodedPayload,
  productId: string,
  uid: string,
  now = Date.now(),
): number {
  appleSubscriptionKey(transaction);
  if (transaction.bundleId !== appleBundleId || transaction.productId !== productId || !appleProducts.has(productId) ||
      transaction.type !== Type.AUTO_RENEWABLE_SUBSCRIPTION || transaction.inAppOwnershipType !== "PURCHASED") {
    throw new Error("Le produit acheté ne correspond pas à Prospecto.");
  }
  if (transaction.appAccountToken?.toLowerCase() !== appleAccountToken(uid)) {
    throw new Error("Cet abonnement appartient à un autre compte Prospecto.");
  }
  if (!/^\d{1,40}$/.test(transaction.transactionId ?? "") ||
      !Number.isSafeInteger(transaction.expiresDate) || !Number.isSafeInteger(transaction.purchaseDate) ||
      (transaction.purchaseDate ?? Infinity) > now + 5 * 60 * 1000 || transaction.revocationDate != null ||
      (transaction.expiresDate ?? 0) <= now) {
    throw new Error("L’abonnement Apple n’est pas actif.");
  }
  return transaction.expiresDate!;
}
