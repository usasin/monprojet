import {
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const region = "europe-west1";
const appId = "prospecto";
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

type JsonRecord = Record<string, unknown>;

type EnterprisePlan = {
  code: "ESSENTIAL" | "TEAM" | "BUSINESS";
  label: string;
  maxSeats: number;
  productId: string;
  priceId: string;
  paymentLink: string;
};

const enterprisePlans: EnterprisePlan[] = [
  {
    code: "ESSENTIAL",
    label: "Essentiel",
    maxSeats: 3,
    productId: "prod_Uyku1j2iTVgHaW",
    priceId: "price_1TynOKGp2jaxM7PLq4fcu2Ua",
    paymentLink: "https://buy.stripe.com/6oU00j72W5u3gMR8QFc3m02",
  },
  {
    code: "TEAM",
    label: "Équipe",
    maxSeats: 10,
    productId: "prod_UykyBeRgLUDzwP",
    priceId: "price_1TynScGp2jaxM7PLFVbREW3h",
    paymentLink: "https://buy.stripe.com/9B614nevo09J68d1odc3m01",
  },
  {
    code: "BUSINESS",
    label: "Business",
    maxSeats: 25,
    productId: "prod_Uyl2SqiZGraCxV",
    priceId: "price_1TynW6Gp2jaxM7PLu0wCPOiB",
    paymentLink: "https://buy.stripe.com/cNi8wP0Eyg8HeEJ4Apc3m00",
  },
];

const plansByPriceId = new Map(enterprisePlans.map((plan) => [plan.priceId, plan]));
const appRoot = db.collection("apps").doc(appId);

function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function objectId(value: unknown): string {
  if (typeof value === "string") return value;
  return stringValue(asRecord(value).id);
}

function normalizeEmail(value: unknown): string {
  const email = stringValue(value).trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : "";
}

function emailHash(email: string): string {
  return createHash("sha256").update(email).digest("hex");
}

function htmlEscape(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function activationCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes(12);
  const chars = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]);
  return `PRO-${chars.slice(0, 4).join("")}-${chars.slice(4, 8).join("")}-${chars.slice(8, 12).join("")}`;
}

async function uniqueActivationCode(): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const code = activationCode();
    const snap = await appRoot.collection("activationCodes").doc(code).get();
    if (!snap.exists) return code;
  }
  throw new Error("Impossible de générer un code d’activation unique.");
}

async function stripeGet(path: string): Promise<JsonRecord> {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${stripeSecretKey.value()}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
  });
  const body = await response.text();
  let parsed: unknown = {};
  try {
    parsed = JSON.parse(body);
  } catch {
    parsed = {message: body};
  }
  if (!response.ok) {
    const error = asRecord(asRecord(parsed).error);
    throw new Error(stringValue(error.message) || `Erreur Stripe HTTP ${response.status}.`);
  }
  return asRecord(parsed);
}

function verifyStripeSignature(rawBody: Buffer, signatureHeader: string, secret: string): void {
  const values = signatureHeader.split(",").map((part) => part.trim());
  const timestampText = values.find((part) => part.startsWith("t="))?.slice(2) ?? "";
  const signatures = values
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3));
  const timestamp = Number(timestampText);
  if (!Number.isFinite(timestamp) || signatures.length === 0) {
    throw new Error("Signature Stripe incomplète.");
  }
  if (Math.abs(Math.floor(Date.now() / 1000) - timestamp) > 300) {
    throw new Error("Événement Stripe trop ancien.");
  }
  const expected = createHmac("sha256", secret)
    .update(`${timestamp}.${rawBody.toString("utf8")}`)
    .digest();
  const valid = signatures.some((signature) => {
    if (!/^[a-f0-9]{64}$/i.test(signature)) return false;
    const received = Buffer.from(signature, "hex");
    return received.length === expected.length && timingSafeEqual(received, expected);
  });
  if (!valid) throw new Error("Signature Stripe invalide.");
}


function priceIdFromLineItem(line: JsonRecord): string {
  const direct = asRecord(line.price);
  const directId = stringValue(direct.id) || objectId(line.price);
  if (directId) return directId;
  const pricing = asRecord(line.pricing);
  const details = asRecord(pricing.price_details);
  return objectId(details.price);
}

function priceIdFromSubscription(subscription: JsonRecord): string {
  const items = asRecord(subscription.items);
  for (const rawItem of asArray(items.data)) {
    const item = asRecord(rawItem);
    const price = asRecord(item.price);
    const id = stringValue(price.id) || objectId(item.price);
    if (plansByPriceId.has(id)) return id;
  }
  return "";
}

function periodEndFromSubscription(subscription: JsonRecord): number {
  const values: number[] = [];
  const legacy = Number(subscription.current_period_end ?? 0);
  if (Number.isFinite(legacy) && legacy > 0) values.push(legacy);
  const items = asRecord(subscription.items);
  for (const rawItem of asArray(items.data)) {
    const item = asRecord(rawItem);
    const value = Number(item.current_period_end ?? 0);
    if (Number.isFinite(value) && value > 0) values.push(value);
  }
  return values.length > 0 ? Math.max(...values) : 0;
}

function subscriptionHasAccess(status: string, periodEndSeconds: number): boolean {
  const validStatuses = new Set(["active", "trialing", "past_due"]);
  return validStatuses.has(status) &&
    (periodEndSeconds <= 0 || periodEndSeconds * 1000 > Date.now());
}

function subscriptionIdFromInvoice(invoice: JsonRecord): string {
  const parent = asRecord(invoice.parent);
  const subscriptionDetails = asRecord(parent.subscription_details);
  return objectId(subscriptionDetails.subscription) || objectId(invoice.subscription);
}

async function customerEmail(session: JsonRecord): Promise<string> {
  const details = asRecord(session.customer_details);
  const direct = normalizeEmail(details.email) || normalizeEmail(session.customer_email);
  if (direct) return direct;
  const customerId = objectId(session.customer);
  if (!customerId) return "";
  const customer = await stripeGet(`customers/${encodeURIComponent(customerId)}`);
  return normalizeEmail(customer.email);
}

async function queueActivationEmail(
  email: string,
  code: string,
  plan: EnterprisePlan,
  sessionId: string,
  resend = false,
): Promise<void> {
  if (!email) return;
  const subject = resend
    ? `Votre code d’activation Prospecto – ${plan.label}`
    : `Activez Prospecto Entreprise – ${plan.label}`;
  const text = [
    "Bonjour,",
    "",
    `Votre abonnement Prospecto Entreprise – ${plan.label} est prêt.`,
    `Ce forfait comprend jusqu’à ${plan.maxSeats} utilisateurs, administrateur principal inclus.`,
    "",
    `Code d’activation : ${code}`,
    "",
    "Dans l’application Prospecto :",
    "1. Choisissez Entreprise",
    "2. Appuyez sur Créer un espace entreprise",
    "3. Saisissez ce code d’activation",
    "",
    "Prospecto — Une solution Digital Solutions AI",
    "Assistance : contact@digitalsolutionsai.com",
  ].join("\n");
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;color:#203040">
      <h2 style="color:#5AACDB">Prospecto Entreprise – ${htmlEscape(plan.label)}</h2>
      <p>Votre abonnement est prêt. Il comprend jusqu’à <strong>${plan.maxSeats} utilisateurs</strong>, administrateur principal inclus.</p>
      <div style="margin:24px 0;padding:18px;border-radius:14px;background:#eef8ff;text-align:center">
        <div style="font-size:13px;color:#637282">Votre code d’activation</div>
        <div style="font-size:25px;font-weight:800;letter-spacing:1px;color:#203040">${htmlEscape(code)}</div>
      </div>
      <p><strong>Dans l’application Prospecto :</strong></p>
      <ol><li>Choisissez « Entreprise »</li><li>Appuyez sur « Créer un espace entreprise »</li><li>Saisissez le code ci-dessus</li></ol>
      <p style="margin-top:28px;color:#637282">Prospecto — Une solution Digital Solutions AI<br>Assistance : contact@digitalsolutionsai.com</p>
    </div>`;
  const suffix = resend ? `-${Date.now()}-${randomBytes(3).toString("hex")}` : "";
  await db.collection("mail").doc(`prospecto-${sessionId}${suffix}`).set({
    to: [email],
    message: {subject, text, html},
    prospecto: {
      type: resend ? "activation_resend" : "activation_created",
      appId,
      sessionId,
      plan: plan.code,
    },
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

type ActivationResult = {
  code: string;
  plan: EnterprisePlan;
  email: string;
  sessionId: string;
  subscriptionId: string;
  subscriptionUntil: Timestamp | null;
};

async function createActivationFromCheckout(session: JsonRecord): Promise<ActivationResult> {
  const sessionId = stringValue(session.id);
  if (!sessionId.startsWith("cs_")) throw new Error("Session Stripe invalide.");
  if (stringValue(session.mode) !== "subscription") {
    throw new Error("Cette session ne correspond pas à un abonnement Prospecto.");
  }
  const sessionStatus = stringValue(session.status);
  const paymentStatus = stringValue(session.payment_status);
  if (sessionStatus !== "complete" || !new Set(["paid", "no_payment_required"]).has(paymentStatus)) {
    throw new Error("Le paiement n’est pas encore confirmé.");
  }

  const lineItems = await stripeGet(
    `checkout/sessions/${encodeURIComponent(sessionId)}/line_items?limit=10`,
  );
  let priceId = "";
  for (const rawLine of asArray(lineItems.data)) {
    const line = asRecord(rawLine);
    const candidate = priceIdFromLineItem(line);
    if (plansByPriceId.has(candidate)) {
      priceId = candidate;
      break;
    }
  }
  const plan = plansByPriceId.get(priceId);
  if (!plan) throw new Error("Le forfait Stripe ne correspond à aucune offre Prospecto.");

  const subscriptionId = objectId(session.subscription);
  if (!subscriptionId.startsWith("sub_")) throw new Error("Abonnement Stripe introuvable.");
  const subscription = await stripeGet(`subscriptions/${encodeURIComponent(subscriptionId)}`);
  const status = stringValue(subscription.status);
  const periodEndSeconds = periodEndFromSubscription(subscription);
  if (!subscriptionHasAccess(status, periodEndSeconds)) {
    throw new Error("L’abonnement Stripe n’est pas actif.");
  }
  const subscriptionUntil = periodEndSeconds > 0
    ? Timestamp.fromMillis(periodEndSeconds * 1000)
    : null;
  const email = await customerEmail(session);
  const customerId = objectId(session.customer) || objectId(subscription.customer);
  const sessionRef = appRoot.collection("stripeCheckoutSessions").doc(sessionId);

  const existing = await sessionRef.get();
  if (existing.exists) {
    const existingCode = stringValue(existing.get("activationCode"));
    if (existingCode) {
      return {code: existingCode, plan, email, sessionId, subscriptionId, subscriptionUntil};
    }
  }

  const code = await uniqueActivationCode();
  const codeRef = appRoot.collection("activationCodes").doc(code);
  const subscriptionRef = appRoot.collection("stripeSubscriptions").doc(subscriptionId);
  const expiresAt = Timestamp.fromMillis(Date.now() + 90 * 24 * 60 * 60 * 1000);

  let finalCode = code;
  await db.runTransaction(async (tx) => {
    const currentSession = await tx.get(sessionRef);
    const alreadyCreated = currentSession.exists
      ? stringValue(currentSession.get("activationCode"))
      : "";
    if (alreadyCreated) {
      finalCode = alreadyCreated;
      return;
    }
    const codeSnap = await tx.get(codeRef);
    if (codeSnap.exists) throw new Error("Collision de code d’activation, recommencez.");
    tx.create(codeRef, {
      active: true,
      used: false,
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      expiresAt,
      subscriptionUntil,
      source: "stripe",
      billingStatus: status,
      paymentIssue: false,
      customerEmail: email,
      stripeCheckoutSessionId: sessionId,
      stripeSubscriptionId: subscriptionId,
      stripeCustomerId: customerId,
      stripePriceId: plan.priceId,
      stripeProductId: plan.productId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(sessionRef, {
      activationCode: code,
      customerEmail: email,
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      stripeSubscriptionId: subscriptionId,
      stripeCustomerId: customerId,
      stripePriceId: plan.priceId,
      stripeProductId: plan.productId,
      paymentStatus,
      status: sessionStatus,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(subscriptionRef, {
      activationCode: code,
      orgId: null,
      customerEmail: email,
      stripeCheckoutSessionId: sessionId,
      stripeCustomerId: customerId,
      stripePriceId: plan.priceId,
      stripeProductId: plan.productId,
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      status,
      accessActive: true,
      paymentIssue: false,
      subscriptionUntil,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (email) {
      tx.set(appRoot.collection("stripeActivationLookups").doc(emailHash(email)), {
        activationCode: code,
        customerEmail: email,
        stripeCheckoutSessionId: sessionId,
        stripeSubscriptionId: subscriptionId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  });

  await queueActivationEmail(email, finalCode, plan, sessionId);
  return {code: finalCode, plan, email, sessionId, subscriptionId, subscriptionUntil};
}

async function syncSubscription(
  subscription: JsonRecord,
  paymentIssueOverride?: boolean,
): Promise<void> {
  const subscriptionId = stringValue(subscription.id);
  if (!subscriptionId.startsWith("sub_")) return;
  const priceId = priceIdFromSubscription(subscription);
  const plan = plansByPriceId.get(priceId);
  if (!plan) {
    console.warn("Abonnement Stripe ignoré : tarif Prospecto inconnu", {subscriptionId, priceId});
    return;
  }
  const status = stringValue(subscription.status);
  const periodEndSeconds = periodEndFromSubscription(subscription);
  const subscriptionUntil = periodEndSeconds > 0
    ? Timestamp.fromMillis(periodEndSeconds * 1000)
    : null;
  const accessActive = subscriptionHasAccess(status, periodEndSeconds);
  const paymentIssue = paymentIssueOverride ?? new Set(["past_due", "unpaid"]).has(status);
  const subscriptionRef = appRoot.collection("stripeSubscriptions").doc(subscriptionId);
  const snap = await subscriptionRef.get();
  const activation = snap.exists ? stringValue(snap.get("activationCode")) : "";
  const orgId = snap.exists ? stringValue(snap.get("orgId")) : "";
  const batch = db.batch();

  batch.set(subscriptionRef, {
    stripePriceId: plan.priceId,
    stripeProductId: plan.productId,
    plan: plan.code,
    planLabel: plan.label,
    maxSeats: plan.maxSeats,
    status,
    accessActive,
    paymentIssue,
    subscriptionUntil,
    canceledAt: subscription.canceled_at
      ? Timestamp.fromMillis(Number(subscription.canceled_at) * 1000)
      : null,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  if (activation) {
    batch.set(appRoot.collection("activationCodes").doc(activation), {
      active: accessActive,
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      subscriptionUntil,
      stripePriceId: plan.priceId,
      stripeProductId: plan.productId,
      billingStatus: status,
      paymentIssue,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  if (orgId) {
    batch.set(appRoot.collection("orgs").doc(orgId), {
      status: accessActive ? "active" : "inactive",
      billingStatus: status,
      paymentIssue,
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      subscriptionUntil,
      stripeSubscriptionId: subscriptionId,
      stripePriceId: plan.priceId,
      stripeProductId: plan.productId,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await batch.commit();
}

async function syncSubscriptionById(subscriptionId: string, paymentIssue?: boolean): Promise<void> {
  if (!subscriptionId.startsWith("sub_")) return;
  const subscription = await stripeGet(`subscriptions/${encodeURIComponent(subscriptionId)}`);
  await syncSubscription(subscription, paymentIssue);
}

function eventObject(event: JsonRecord): JsonRecord {
  return asRecord(asRecord(event.data).object);
}

export const stripeWebhook = onRequest({
  region,
  timeoutSeconds: 120,
  secrets: [stripeSecretKey, stripeWebhookSecret],
}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).send("Méthode non autorisée.");
    return;
  }
  try {
    const signature = stringValue(request.headers["stripe-signature"]);
    if (!signature) throw new Error("En-tête stripe-signature absent.");
    verifyStripeSignature(request.rawBody, signature, stripeWebhookSecret.value());
    const event = asRecord(JSON.parse(request.rawBody.toString("utf8")));
    const eventId = stringValue(event.id);
    const eventType = stringValue(event.type);
    if (!eventId.startsWith("evt_")) throw new Error("Événement Stripe invalide.");
    const eventRef = appRoot.collection("stripeEvents").doc(eventId);
    if ((await eventRef.get()).exists) {
      response.status(200).json({received: true, duplicate: true});
      return;
    }

    const object = eventObject(event);
    switch (eventType) {
      case "checkout.session.completed":
        if (new Set(["paid", "no_payment_required"]).has(stringValue(object.payment_status))) {
          await createActivationFromCheckout(object);
        }
        break;
      case "checkout.session.async_payment_succeeded":
        await createActivationFromCheckout(object);
        break;
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted":
        await syncSubscription(object);
        break;
      case "invoice.paid":
        await syncSubscriptionById(subscriptionIdFromInvoice(object), false);
        break;
      case "invoice.payment_failed":
        await syncSubscriptionById(subscriptionIdFromInvoice(object), true);
        break;
      default:
        break;
    }

    await eventRef.set({
      type: eventType,
      processedAt: FieldValue.serverTimestamp(),
    });
    response.status(200).json({received: true});
  } catch (error) {
    console.error("Stripe webhook error", error);
    response.status(400).send(error instanceof Error ? error.message : "Webhook Stripe invalide.");
  }
});

function activationPageHtml(result: ActivationResult): string {
  const code = htmlEscape(result.code);
  const plan = htmlEscape(result.plan.label);
  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Activation Prospecto</title>
<style>
body{margin:0;font-family:Arial,sans-serif;background:linear-gradient(145deg,#f6fbff,#eaf7f3,#fff3f0);color:#203040;min-height:100vh;display:grid;place-items:center;padding:20px;box-sizing:border-box}
.card{width:min(620px,100%);background:rgba(255,255,255,.88);border:1px solid rgba(90,172,219,.25);border-radius:24px;box-shadow:0 18px 55px rgba(32,48,64,.12);padding:30px;box-sizing:border-box}.brand{display:flex;align-items:center;gap:12px}.logo{width:52px;height:52px;border-radius:16px;background:linear-gradient(135deg,#5AACDB,#3CC398);display:grid;place-items:center;color:white;font-size:27px;font-weight:900}.tag{display:inline-block;background:#e9f8f2;color:#218467;padding:7px 11px;border-radius:999px;font-weight:700;font-size:13px}.code{margin:24px 0;background:#eef8ff;border:1px dashed #5AACDB;border-radius:16px;padding:20px;text-align:center;font-size:25px;font-weight:900;letter-spacing:1px;word-break:break-word}.button{border:0;border-radius:12px;background:linear-gradient(135deg,#5AACDB,#3CC398);color:white;padding:13px 18px;font-weight:800;cursor:pointer;width:100%;font-size:15px}.steps{line-height:1.7;padding-left:22px}.foot{color:#637282;font-size:13px;margin-top:24px}.ok{color:#218467;font-weight:800}</style></head>
<body><main class="card"><div class="brand"><div class="logo">P</div><div><h1 style="margin:0;font-size:25px">Prospecto Entreprise</h1><div style="color:#637282;margin-top:4px">Une solution Digital Solutions AI</div></div></div>
<p class="ok">✓ Votre abonnement est activé</p><span class="tag">Forfait ${plan} · ${result.plan.maxSeats} utilisateurs maximum</span>
<div class="code" id="code">${code}</div><button class="button" onclick="navigator.clipboard.writeText(document.getElementById('code').innerText);this.innerText='Code copié ✓'">Copier le code d’activation</button>
<h2 style="font-size:18px;margin-top:26px">Dans l’application Prospecto</h2><ol class="steps"><li>Choisissez <strong>Entreprise</strong></li><li>Appuyez sur <strong>Créer un espace entreprise</strong></li><li>Saisissez le code affiché ci-dessus</li></ol>
<p class="foot">Conservez ce code jusqu’à la création de votre espace. Assistance : contact@digitalsolutionsai.com</p></main></body></html>`;
}

function errorPageHtml(message: string): string {
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Prospecto</title></head><body style="font-family:Arial,sans-serif;background:#f6fbff;color:#203040;padding:30px"><main style="max-width:620px;margin:50px auto;background:white;padding:28px;border-radius:20px;box-shadow:0 16px 45px rgba(32,48,64,.12)"><h1 style="color:#5AACDB">Prospecto</h1><h2>Activation en cours</h2><p>${htmlEscape(message)}</p><p>Patientez quelques instants puis actualisez cette page. En cas de besoin : contact@digitalsolutionsai.com</p></main></body></html>`;
}

export const stripeActivationPage = onRequest({
  region,
  timeoutSeconds: 120,
  secrets: [stripeSecretKey],
}, async (request, response) => {
  response.set("Cache-Control", "no-store, max-age=0");
  response.set("Content-Type", "text/html; charset=utf-8");
  if (request.method !== "GET") {
    response.status(405).send(errorPageHtml("Méthode non autorisée."));
    return;
  }
  const sessionId = stringValue(request.query.session_id);
  if (!/^cs_[A-Za-z0-9_]+$/.test(sessionId) || sessionId.length > 300) {
    response.status(400).send(errorPageHtml("Le numéro de session Stripe est absent ou invalide."));
    return;
  }
  try {
    const session = await stripeGet(`checkout/sessions/${encodeURIComponent(sessionId)}`);
    const result = await createActivationFromCheckout(session);
    response.status(200).send(activationPageHtml(result));
  } catch (error) {
    console.error("Stripe activation page error", error);
    response.status(202).send(errorPageHtml(
      error instanceof Error ? error.message : "Le paiement est encore en cours de confirmation.",
    ));
  }
});

export const resendStripeActivationCode = onCall({
  region,
  timeoutSeconds: 60,
}, async (request) => {
  const email = normalizeEmail(request.data?.email);
  if (!email) throw new HttpsError("invalid-argument", "Adresse e-mail invalide.");
  const lookupRef = appRoot.collection("stripeActivationLookups").doc(emailHash(email));
  const lookup = await lookupRef.get();
  // Réponse volontairement générique pour ne pas révéler si une adresse est cliente.
  if (!lookup.exists) return {sent: true};
  const code = stringValue(lookup.get("activationCode"));
  const sessionId = stringValue(lookup.get("stripeCheckoutSessionId"));
  const lastResentAt = lookup.get("lastResentAt") as Timestamp | undefined;
  if (lastResentAt && Date.now() - lastResentAt.toMillis() < 5 * 60 * 1000) {
    return {sent: true};
  }
  const codeSnap = await appRoot.collection("activationCodes").doc(code).get();
  if (!codeSnap.exists || codeSnap.get("used") === true || codeSnap.get("active") !== true) {
    return {sent: true};
  }
  const planCode = stringValue(codeSnap.get("plan"));
  const plan = enterprisePlans.find((entry) => entry.code === planCode);
  if (!plan || !sessionId) return {sent: true};
  await queueActivationEmail(email, code, plan, sessionId, true);
  await lookupRef.set({lastResentAt: FieldValue.serverTimestamp()}, {merge: true});
  return {sent: true};
});
