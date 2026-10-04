import {readFileSync} from "node:fs";
import {join} from "node:path";
import {Environment, SignedDataVerifier, JWSTransactionDecodedPayload, ResponseBodyV2DecodedPayload} from "@apple/app-store-server-library";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {appleAccountToken, appleAppId, appleBundleId, appleProducts, appleSubscriptionKey, validateApplePurchase} from "./apple_purchase_logic";

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const region = "europe-west1";
const roots = [readFileSync(join(__dirname, "../certificates/AppleRootCA-G3.pem"))];
// Online certificate expiration and OCSP checks are enabled. Never accept Xcode/local-testing unsigned payloads.
const verifiers = [Environment.PRODUCTION, Environment.SANDBOX].map(
  (environment) => new SignedDataVerifier(roots, true, environment, appleBundleId, appleAppId),
);

export async function verifyAppleSignedTransaction(signed: string): Promise<JWSTransactionDecodedPayload> {
  for (const verifier of verifiers) {
    try { return await verifier.verifyAndDecodeTransaction(signed); } catch { /* Try the other Apple environment. */ }
  }
  throw new HttpsError("permission-denied", "Transaction non reconnue par Apple.");
}

async function verifyNotification(signed: string): Promise<ResponseBodyV2DecodedPayload> {
  for (const verifier of verifiers) {
    try { return await verifier.verifyAndDecodeNotification(signed); } catch { /* Fail closed after both environments. */ }
  }
  throw new Error("Notification non reconnue par Apple.");
}

export const getApplePurchaseAccount = onCall({region}, (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Connectez-vous avant un achat.");
  return {appAccountToken: appleAccountToken(request.auth.uid)};
});

export const verifyApplePurchase = onCall({region, timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connectez-vous pour restaurer votre abonnement.");
  const productId = request.data?.productId;
  const signed = request.data?.signedTransaction;
  if (typeof productId !== "string" || !appleProducts.has(productId) || typeof signed !== "string" ||
      signed.length < 100 || signed.length > 30000 || signed.split(".").length !== 3) {
    throw new HttpsError("invalid-argument", "Transaction Apple invalide.");
  }
  const transaction = await verifyAppleSignedTransaction(signed);
  let expiryMs: number;
  try { expiryMs = validateApplePurchase(transaction, productId, uid); }
  catch (error) { throw new HttpsError("failed-precondition", error instanceof Error ? error.message : "Abonnement invalide."); }
  const key = appleSubscriptionKey(transaction);
  const ref = db.collection("appStoreSubscriptions").doc(key);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const [previous, user] = await Promise.all([tx.get(ref), tx.get(userRef)]);
    if (previous.exists && previous.get("uid") && previous.get("uid") !== uid) {
      throw new HttpsError("already-exists", "Cet achat est déjà associé à un autre compte.");
    }
    const old = previous.data();
    const newer = Number(old?.signedDate ?? 0) > Number(transaction.signedDate ?? 0);
    if (old?.revocationDate && old.transactionId === transaction.transactionId || newer && old?.active === false) {
      throw new HttpsError("failed-precondition", "Apple a révoqué ou terminé cet abonnement.");
    }
    if (newer) expiryMs = Math.max(expiryMs, Number(old?.expiresDate ?? 0));
    tx.set(ref, {
      uid, productId, bundleId: appleBundleId, environment: transaction.environment,
      originalTransactionId: transaction.originalTransactionId, appAccountToken: appleAccountToken(uid),
      ...(newer ? {} : {transactionId: transaction.transactionId, signedDate: transaction.signedDate ?? 0,
        expiresDate: expiryMs, revocationDate: null, active: true}),
      checkedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    // A sandbox restore must not replace an active production or Google Play subscription.
    const entitlement = user.get("entitlements") ?? {};
    const currentUntil = entitlement.premiumUntil?.toMillis?.() ?? 0;
    if (currentUntil > expiryMs || transaction.environment === Environment.SANDBOX &&
        currentUntil > Date.now() && entitlement.appleEnvironment === Environment.PRODUCTION) return;
    tx.set(userRef, {entitlements: {
      isPremium: true, activePlan: productId === "premium_yearly" ? "PREMIUM_YEARLY" : "PREMIUM_MONTHLY",
      productId, premiumUntil: Timestamp.fromMillis(expiryMs), billingProvider: "app_store",
      appleSubscriptionKey: key, appleEnvironment: transaction.environment,
      verifiedAt: FieldValue.serverTimestamp(), subscriptionState: "ACTIVE",
    }}, {merge: true});
  });
  return {delivered: true, active: true, productId, premiumUntil: new Date(expiryMs).toISOString()};
});

// Configure this HTTPS URL for both production and sandbox App Store Server Notifications V2.
export const appStoreNotifications = onRequest({region, timeoutSeconds: 60}, async (request, response) => {
  if (request.method !== "POST") { response.status(405).send("POST required"); return; }
  const signed = request.body?.signedPayload;
  if (typeof signed !== "string" || signed.length > 60000) { response.status(400).send("Invalid notification"); return; }
  let notification: ResponseBodyV2DecodedPayload;
  let transaction: JWSTransactionDecodedPayload;
  try {
    notification = await verifyNotification(signed);
    if (notification.notificationType === "TEST") { response.status(200).send("OK"); return; }
    const signedTransaction = notification.data?.signedTransactionInfo;
    if (!signedTransaction) { response.status(200).send("OK"); return; }
    transaction = await verifyAppleSignedTransaction(signedTransaction);
    if (transaction.environment !== notification.data?.environment || !appleProducts.has(transaction.productId ?? "")) {
      throw new Error("Unrelated transaction");
    }
  } catch {
    response.status(400).send("Invalid Apple signature"); return;
  }
  const key = appleSubscriptionKey(transaction);
  const ref = db.collection("appStoreSubscriptions").doc(key);
  const expiryMs = transaction.expiresDate ?? 0;
  const active = transaction.revocationDate == null && expiryMs > Date.now();
  const signedDate = Math.max(notification.signedDate ?? 0, transaction.signedDate ?? 0);
  try {
    await db.runTransaction(async (tx) => {
      const previous = await tx.get(ref);
      if (Number(previous.get("signedDate") ?? 0) > signedDate) return;
      const uid = previous.get("uid");
      const userRef = typeof uid === "string" ? db.collection("users").doc(uid) : null;
      const user = userRef ? await tx.get(userRef) : null;
      tx.set(ref, {
        productId: transaction.productId, environment: transaction.environment,
        originalTransactionId: transaction.originalTransactionId, transactionId: transaction.transactionId,
        appAccountToken: transaction.appAccountToken ?? null, expiresDate: expiryMs,
        revocationDate: transaction.revocationDate ?? null, signedDate, active,
        lastNotification: notification.notificationType ?? null, checkedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      const entitlement = user?.get("entitlements") ?? {};
      if (!userRef || entitlement.appleSubscriptionKey !== key || entitlement.billingProvider !== "app_store") return;
      tx.set(userRef, {entitlements: {
        isPremium: active, activePlan: active ? (transaction.productId === "premium_yearly" ? "PREMIUM_YEARLY" : "PREMIUM_MONTHLY") : "FREE",
        productId: transaction.productId, premiumUntil: Timestamp.fromMillis(expiryMs),
        verifiedAt: FieldValue.serverTimestamp(), subscriptionState: active ? "ACTIVE" : "EXPIRED_OR_REVOKED",
      }}, {merge: true});
    });
    response.status(200).send("OK");
  } catch {
    // Apple retries server errors; never log receipts, tokens or signed payloads.
    response.status(500).send("Notification processing unavailable");
  }
});
