import {salesPayload, assertSalesRevision, needsSalesCorrection} from "./sales_logic";
import {createHash, randomBytes} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {DocumentData, DocumentReference, FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {google} from "googleapis";

export {stripeWebhook, stripeActivationPage, resendStripeActivationCode} from "./stripe_enterprise";

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const region = "europe-west1";
const packageName = "com.ainego.ai_prospect_gps";
const allowedProducts = new Set(["premium_monthly", "premium_yearly"]);

function requireUser(request: {auth?: {uid: string} | null}): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connectez-vous pour continuer.");
  return uid;
}

function requireRecentAuthentication(
  request: {auth?: {token?: Record<string, unknown>} | null},
  maxAgeSeconds = 15 * 60,
): void {
  const rawAuthTime = request.auth?.token?.auth_time;
  const authTime = typeof rawAuthTime === "number"
    ? rawAuthTime
    : Number(rawAuthTime ?? 0);
  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  if (!Number.isFinite(authTime) || authTime <= 0 || ageSeconds > maxAgeSeconds) {
    throw new HttpsError(
      "failed-precondition",
      "Pour votre sécurité, déconnectez-vous puis reconnectez-vous avant de supprimer le compte.",
    );
  }
}

function requireText(value: unknown, name: string, max = 160): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text || text.length > max) {
    throw new HttpsError("invalid-argument", `${name} invalide.`);
  }
  return text;
}

function appPath(appId: string): DocumentReference {
  if (!/^[a-z0-9_-]{2,40}$/i.test(appId)) {
    throw new HttpsError("invalid-argument", "Application invalide.");
  }
  return db.collection("apps").doc(appId);
}

function inviteCode(): string {
  return randomBytes(16).toString("hex").toUpperCase();
}

async function memberRole(appId: string, orgId: string, uid: string): Promise<string | null> {
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const org = await orgRef.get();
  if (!org.exists || !subscriptionIsActive(org.data() ?? {})) return null;
  const snap = await orgRef.collection("members").doc(uid).get();
  if (!snap.exists || snap.get("status") !== "active") return null;
  return String(snap.get("role") ?? "REP").toUpperCase();
}

function requireDateId(value: unknown): string {
  const text = requireText(value, "Date", 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text) || Number.isNaN(Date.parse(`${text}T12:00:00Z`))) {
    throw new HttpsError("invalid-argument", "Date invalide.");
  }
  return text;
}

function stringArray(value: unknown, name: string, maxItems = 100): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${name} invalide.`);
  }
  const values = [...new Set(value.map((item) => String(item ?? "").trim()).filter(Boolean))];
  if (values.length === 0 || values.length > maxItems) {
    throw new HttpsError("invalid-argument", `${name} doit contenir entre 1 et ${maxItems} éléments.`);
  }
  return values;
}

async function notifyUser(uid: string, title: string, body: string, data: Record<string, string> = {}): Promise<void> {
  try {
    const user = await db.collection("users").doc(uid).get();
    if (user.get("notificationsEnabled") === false) return;
    const tokensMap = user.get("fcmTokens") as Record<string, unknown> | undefined;
    const tokens = Object.keys(tokensMap ?? {}).slice(0, 100);
    if (tokens.length === 0) return;
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data,
      android: {priority: "high", notification: {channelId: "prospecto_reminders"}},
    });
  } catch (error) {
    console.warn("Notification Prospecto non envoyée", uid, error);
  }
}

function optionalText(value: unknown, max: number): string {
  if (value == null) return "";
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length > max) {
    throw new HttpsError("invalid-argument", "Texte trop long.");
  }
  return text;
}

function optionalEmail(value: unknown): string {
  const email = optionalText(value, 254).toLowerCase();
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Adresse e-mail invalide.");
  }
  return email;
}

function existingTeamId(data: DocumentData): string {
  const currentType = String(data.currentOrgType ?? "").toLowerCase();
  const value = data.teamOrgId
    ?? (currentType === "team" ? data.currentOrgId : null)
    ?? (currentType === "team" ? data.orgId : null)
    ?? "";
  return String(value).trim();
}

function actorEmail(request: {auth?: {token?: Record<string, unknown>} | null}): string {
  const value = request.auth?.token?.email;
  return typeof value === "string" ? value : "";
}

function activityData(
  request: {auth?: {uid: string; token?: Record<string, unknown>} | null},
  action: string,
  message: string,
  targetUid?: string,
): Record<string, unknown> {
  return {
    action,
    message,
    actorUid: request.auth?.uid ?? "",
    actorEmail: actorEmail(request),
    targetUid: targetUid ?? null,
    createdAt: FieldValue.serverTimestamp(),
  };
}

function subscriptionIsActive(data: DocumentData): boolean {
  if (String(data.status ?? "active").toLowerCase() !== "active") return false;
  const until = data.subscriptionUntil as Timestamp | null | undefined;
  return !until || until.toMillis() > Date.now();
}

type DeveloperPlanCode = "ESSENTIAL" | "TEAM" | "BUSINESS";

type DeveloperPlan = {
  code: DeveloperPlanCode;
  label: string;
  maxSeats: number;
};

const developerPlans: Record<DeveloperPlanCode, DeveloperPlan> = {
  ESSENTIAL: {code: "ESSENTIAL", label: "Essentiel", maxSeats: 3},
  TEAM: {code: "TEAM", label: "Équipe", maxSeats: 10},
  BUSINESS: {code: "BUSINESS", label: "Business", maxSeats: 25},
};

function requireDeveloper(
  request: {auth?: {uid: string; token?: Record<string, unknown>} | null},
): string {
  const uid = requireUser(request);
  if (request.auth?.token?.prospectoDeveloper !== true) {
    throw new HttpsError(
      "permission-denied",
      "Ce compte ne possède pas l’accès développeur Prospecto.",
    );
  }
  return uid;
}

function developerPlan(value: unknown): DeveloperPlan {
  const code = String(value ?? "TEAM").trim().toUpperCase() as DeveloperPlanCode;
  const plan = developerPlans[code];
  if (!plan) {
    throw new HttpsError(
      "invalid-argument",
      "Forfait développeur invalide.",
    );
  }
  return plan;
}

function developerActivationCode(): string {
  return `DEV-${randomBytes(5).toString("hex").toUpperCase()}`;
}

export const createDeveloperActivationCode = onCall({region}, async (request) => {
  const uid = requireDeveloper(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const plan = developerPlan(request.data?.plan);
  const root = appPath(appId);

  let code = developerActivationCode();
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const existing = await root.collection("activationCodes").doc(code).get();
    if (!existing.exists) break;
    code = developerActivationCode();
  }

  const now = Date.now();
  await root.collection("activationCodes").doc(code).create({
    active: true,
    used: false,
    plan: plan.code,
    planLabel: plan.label,
    maxSeats: plan.maxSeats,
    source: "developer",
    developerTest: true,
    developerUid: uid,
    billingSource: "developer",
    billingStatus: "developer",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(now + 7 * 24 * 60 * 60 * 1000),
    subscriptionUntil: Timestamp.fromMillis(now + 365 * 24 * 60 * 60 * 1000),
  });

  return {
    code,
    plan: plan.code,
    planLabel: plan.label,
    maxSeats: plan.maxSeats,
  };
});

export const setDeveloperOrganizationPlan = onCall({region}, async (request) => {
  const uid = requireDeveloper(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const plan = developerPlan(request.data?.plan);
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(uid);

  await db.runTransaction(async (tx) => {
    const [orgSnap, memberSnap] = await Promise.all([
      tx.get(orgRef),
      tx.get(memberRef),
    ]);
    if (!orgSnap.exists || orgSnap.get("developerTest") !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Seule une entreprise de test développeur peut changer de forfait sans paiement.",
      );
    }
    if (!memberSnap.exists || String(memberSnap.get("role") ?? "").toUpperCase() !== "OWNER") {
      throw new HttpsError(
        "permission-denied",
        "Seul l’administrateur principal peut modifier le forfait de test.",
      );
    }
    tx.update(orgRef, {
      plan: plan.code,
      planLabel: plan.label,
      maxSeats: plan.maxSeats,
      status: "active",
      billingSource: "developer",
      billingStatus: "developer",
      paymentIssue: false,
      subscriptionUntil: Timestamp.fromMillis(
        Date.now() + 365 * 24 * 60 * 60 * 1000,
      ),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(orgRef.collection("activity").doc(), activityData(
      request,
      "developer_plan_changed",
      `Forfait de test changé vers ${plan.label} (${plan.maxSeats} places).`,
    ));
  });

  return {
    plan: plan.code,
    planLabel: plan.label,
    maxSeats: plan.maxSeats,
  };
});

export const deleteDeveloperOrganization = onCall({
  region,
  timeoutSeconds: 120,
}, async (request) => {
  const uid = requireDeveloper(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const root = appPath(appId);
  const orgRef = root.collection("orgs").doc(orgId);
  const [orgSnap, memberSnap] = await Promise.all([
    orgRef.get(),
    orgRef.collection("members").doc(uid).get(),
  ]);

  if (!orgSnap.exists || orgSnap.get("developerTest") !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Cette organisation n’est pas une entreprise de test développeur.",
    );
  }
  if (!memberSnap.exists || String(memberSnap.get("role") ?? "").toUpperCase() !== "OWNER") {
    throw new HttpsError(
      "permission-denied",
      "Seul l’administrateur principal peut réinitialiser cette entreprise de test.",
    );
  }

  await db.recursiveDelete(orgRef);
  await db.collection("users").doc(uid).set({
    currentOrgType: "personal",
    currentOrgId: FieldValue.delete(),
    currentOrgName: FieldValue.delete(),
    currentRole: FieldValue.delete(),
    orgId: FieldValue.delete(),
    orgName: FieldValue.delete(),
    role: FieldValue.delete(),
    teamOrgId: FieldValue.delete(),
    teamOrgName: FieldValue.delete(),
    teamRole: FieldValue.delete(),
    orgIds: FieldValue.arrayRemove(orgId),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {deleted: true};
});

export const precheckActivationCode = onCall({region}, async (request) => {
  const appId = requireText(request.data?.appId, "appId", 40);
  const code = requireText(request.data?.code, "code", 80).toUpperCase();
  const ref = appPath(appId).collection("activationCodes").doc(code);
  const snap = await ref.get();
  if (!snap.exists || snap.get("active") !== true || snap.get("used") === true) {
    throw new HttpsError("not-found", "Code d’activation invalide ou déjà utilisé.");
  }
  const expiresAt = snap.get("expiresAt") as Timestamp | undefined;
  if (expiresAt && expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError("failed-precondition", "Ce code d’activation a expiré.");
  }
  return {
    plan: String(snap.get("plan") ?? "STANDARD"),
    planLabel: String(snap.get("planLabel") ?? snap.get("plan") ?? "Standard"),
    maxSeats: Number(snap.get("maxSeats") ?? 5),
  };
});

export const createOrgWithActivation = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const name = requireText(request.data?.name, "Nom de l’organisation", 100);
  const code = requireText(request.data?.activationCode, "Code", 80).toUpperCase();
  const root = appPath(appId);
  const codeRef = root.collection("activationCodes").doc(code);
  const orgRef = root.collection("orgs").doc();
  const userRef = db.collection("users").doc(uid);
  const email = typeof request.auth?.token.email === "string" ? request.auth.token.email : "";

  await db.runTransaction(async (tx) => {
    const [codeSnap, userSnap] = await Promise.all([
      tx.get(codeRef),
      tx.get(userRef),
    ]);
    const linkedTeamId = existingTeamId(userSnap.data() ?? {});
    if (linkedTeamId) {
      throw new HttpsError(
        "already-exists",
        "Ce compte appartient déjà à une entreprise. Quittez-la avant d’en créer une autre.",
      );
    }
    if (!codeSnap.exists || codeSnap.get("active") !== true || codeSnap.get("used") === true) {
      throw new HttpsError("failed-precondition", "Code invalide ou déjà utilisé.");
    }
    const expiresAt = codeSnap.get("expiresAt") as Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "Code expiré.");
    }
    const plan = String(codeSnap.get("plan") ?? "STANDARD");
    const planLabel = String(codeSnap.get("planLabel") ?? plan);
    const maxSeats = Number(codeSnap.get("maxSeats") ?? 5);
    const subscriptionUntil = codeSnap.get("subscriptionUntil") as Timestamp | undefined;
    const stripeSubscriptionId = String(codeSnap.get("stripeSubscriptionId") ?? "");
    const stripeCustomerId = String(codeSnap.get("stripeCustomerId") ?? "");
    const stripePriceId = String(codeSnap.get("stripePriceId") ?? "");
    const stripeProductId = String(codeSnap.get("stripeProductId") ?? "");
    const stripeCheckoutSessionId = String(codeSnap.get("stripeCheckoutSessionId") ?? "");
    const billingStatus = String(codeSnap.get("billingStatus") ?? (stripeSubscriptionId ? "active" : "manual"));
    const paymentIssue = codeSnap.get("paymentIssue") === true;
    const developerTest = codeSnap.get("developerTest") === true;
    const developerUid = String(codeSnap.get("developerUid") ?? "");
    if (developerTest && developerUid && developerUid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Ce code de test développeur appartient à un autre compte.",
      );
    }
    tx.create(orgRef, {
      name,
      plan,
      planLabel,
      maxSeats,
      subscriptionUntil: subscriptionUntil ?? null,
      billingSource: developerTest ? "developer" : (stripeSubscriptionId ? "stripe" : "manual"),
      billingStatus: developerTest ? "developer" : billingStatus,
      paymentIssue: developerTest ? false : paymentIssue,
      developerTest,
      developerUid: developerTest ? uid : null,
      stripeSubscriptionId: stripeSubscriptionId || null,
      stripeCustomerId: stripeCustomerId || null,
      stripePriceId: stripePriceId || null,
      stripeProductId: stripeProductId || null,
      stripeCheckoutSessionId: stripeCheckoutSessionId || null,
      createdBy: uid,
      ownerUid: uid,
      createdAt: FieldValue.serverTimestamp(),
      status: "active",
      logoUrl: "",
      slogan: "",
      companyEmail: "",
      companyPhone: "",
      website: "",
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(orgRef.collection("members").doc(uid), {
      uid,
      email,
      role: "OWNER",
      status: "active",
      routeAutonomy: true,
      joinedAt: FieldValue.serverTimestamp(),
      lastActivityAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, {
      currentOrgId: orgRef.id,
      currentOrgName: name,
      currentRole: "OWNER",
      currentOrgType: "team",
      orgId: orgRef.id,
      orgName: name,
      role: "OWNER",
      teamOrgId: orgRef.id,
      teamOrgName: name,
      teamRole: "OWNER",
      orgIds: FieldValue.arrayUnion(orgRef.id),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(orgRef.collection("activity").doc(), activityData(
      request,
      "organization_created",
      `Espace entreprise « ${name} » créé.`,
    ));
    tx.update(codeRef, {
      used: true,
      usedBy: uid,
      usedAt: FieldValue.serverTimestamp(),
      orgId: orgRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (stripeSubscriptionId) {
      tx.set(root.collection("stripeSubscriptions").doc(stripeSubscriptionId), {
        orgId: orgRef.id,
        activationCode: code,
        ownerUid: uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  });
  return {orgId: orgRef.id, orgName: name, role: "OWNER"};
});

export const createOrgInvite = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const role = requireText(request.data?.role ?? "REP", "Rôle", 20).toUpperCase();
  if (!new Set(["REP", "MANAGER"]).has(role)) {
    throw new HttpsError("invalid-argument", "Rôle non autorisé.");
  }
  const currentRole = await memberRole(appId, orgId, uid);
  if (currentRole !== "OWNER") {
    throw new HttpsError("permission-denied", "Seul l’administrateur principal peut inviter un membre.");
  }
  const firstName = requireText(request.data?.firstName, "Prénom", 80);
  const lastName = requireText(request.data?.lastName, "Nom", 80);
  const email = optionalEmail(requireText(request.data?.email, "E-mail", 254));
  const managerUid = role === "REP" ? String(request.data?.managerUid ?? "").trim() : "";
  if (managerUid && await memberRole(appId, orgId, managerUid) !== "MANAGER") {
    throw new HttpsError("invalid-argument", "Responsable commercial inactif ou invalide.");
  }
  const root = appPath(appId);
  const orgRef = root.collection("orgs").doc(orgId);
  const org = await orgRef.get();
  if (!org.exists || !subscriptionIsActive(org.data() ?? {})) {
    throw new HttpsError("failed-precondition", "L’espace entreprise n’est pas actif.");
  }
  const members = await orgRef.collection("members").where("status", "==", "active").count().get();
  const maxSeats = Number(org.get("maxSeats") ?? 5);
  if (members.data().count >= maxSeats) {
    throw new HttpsError("resource-exhausted", "Nombre maximal de membres atteint.");
  }

  const code = inviteCode();
  const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const inviteRef = orgRef.collection("invites").doc(code);
  const lookupRef = root.collection("inviteCodes").doc(code);
  const batch = db.batch();
  batch.create(inviteRef, {
    code, role, email, firstName, lastName, managerUid, active: true, createdBy: uid,
    createdAt: FieldValue.serverTimestamp(), expiresAt,
  });
  batch.create(lookupRef, {orgId, active: true, expiresAt});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "invite_created",
    `Invitation ${role === "MANAGER" ? "responsable commercial" : "commercial"} créée.`,
  ));
  await batch.commit();
  return {code, expiresAt: expiresAt.toDate().toISOString()};
});

// The invitation is a high-entropy bearer secret. The preview exposes only the
// invitation identity, never membership data or administrative information.
export const previewOrgInvite = onCall({region}, async (request) => {
  const appId = requireText(request.data?.appId, "appId", 40);
  const code = requireText(request.data?.code, "Code", 80).toUpperCase();
  const root = appPath(appId);
  const lookup = await root.collection("inviteCodes").doc(code).get();
  if (!lookup.exists || lookup.get("active") !== true ||
      !(lookup.get("expiresAt") instanceof Timestamp) || lookup.get("expiresAt").toMillis() <= Date.now()) {
    throw new HttpsError("not-found", "Invitation invalide, déjà utilisée ou expirée.");
  }
  const orgRef = root.collection("orgs").doc(String(lookup.get("orgId")));
  const [org, invite] = await Promise.all([orgRef.get(), orgRef.collection("invites").doc(code).get()]);
  if (!org.exists || !subscriptionIsActive(org.data() ?? {}) || invite.get("active") !== true || !invite.get("email")) {
    throw new HttpsError("failed-precondition", "Demandez une nouvelle invitation nominative à votre administrateur.");
  }
  return {orgName: org.get("name"), email: invite.get("email"),
    firstName: invite.get("firstName") ?? "", lastName: invite.get("lastName") ?? "", role: invite.get("role")};
});

export const assignMemberManager = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Commercial", 128);
  const managerUid = String(request.data?.managerUid ?? "").trim();
  if (await memberRole(appId, orgId, uid) !== "OWNER") throw new HttpsError("permission-denied", "Action réservée à l’administrateur principal.");
  if (await memberRole(appId, orgId, memberUid) !== "REP") throw new HttpsError("invalid-argument", "Commercial inactif ou invalide.");
  if (managerUid && await memberRole(appId, orgId, managerUid) !== "MANAGER") throw new HttpsError("invalid-argument", "Responsable inactif ou invalide.");
  await appPath(appId).collection("orgs").doc(orgId).collection("members").doc(memberUid)
    .update({managerUid, updatedAt: FieldValue.serverTimestamp()});
  return {updated: true};
});

async function requireManagedMember(appId: string, orgId: string, uid: string, memberUid: string, allowSelf = false): Promise<void> {
  const role = await memberRole(appId, orgId, uid);
  if (allowSelf && uid === memberUid && role) return;
  if (role === "OWNER") return;
  const target = await appPath(appId).collection("orgs").doc(orgId).collection("members").doc(memberUid).get();
  if (role !== "MANAGER" || target.get("role") !== "REP" || target.get("managerUid") !== uid) {
    throw new HttpsError("permission-denied", "Ce commercial ne fait pas partie de votre équipe.");
  }
}

export const acceptOrgInvite = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const code = requireText(request.data?.code, "Code", 80).toUpperCase();
  const root = appPath(appId);
  const lookupRef = root.collection("inviteCodes").doc(code);
  const userRef = db.collection("users").doc(uid);
  const email = typeof request.auth?.token.email === "string"
    ? request.auth.token.email.toLowerCase() : "";
  if (!email || request.auth?.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "Vérifiez votre adresse e-mail avant d’activer l’invitation.");
  }
  let response = {orgId: "", orgName: "", role: "REP"};

  await db.runTransaction(async (tx) => {
    const [lookup, userSnap] = await Promise.all([
      tx.get(lookupRef),
      tx.get(userRef),
    ]);
    if (!lookup.exists || lookup.get("active") !== true) {
      throw new HttpsError("not-found", "Invitation invalide.");
    }
    const expiresAt = lookup.get("expiresAt") as Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "Invitation expirée.");
    }
    const orgId = String(lookup.get("orgId"));
    const linkedTeamId = existingTeamId(userSnap.data() ?? {});
    if (linkedTeamId && linkedTeamId !== orgId) {
      throw new HttpsError(
        "already-exists",
        "Ce compte appartient déjà à une autre entreprise.",
      );
    }
    const orgRef = root.collection("orgs").doc(orgId);
    const inviteRef = orgRef.collection("invites").doc(code);
    const [org, invite] = await Promise.all([tx.get(orgRef), tx.get(inviteRef)]);
    if (!org.exists || !subscriptionIsActive(org.data() ?? {}) ||
        !invite.exists || invite.get("active") !== true) {
      throw new HttpsError("failed-precondition", "Invitation ou espace entreprise indisponible.");
    }
    const restrictedEmail = String(invite.get("email") ?? "").toLowerCase();
    if (!restrictedEmail) throw new HttpsError("failed-precondition", "Demandez une nouvelle invitation nominative à votre administrateur.");
    if (restrictedEmail !== email) {
      throw new HttpsError("permission-denied", `Cette invitation est réservée à ${restrictedEmail}`);
    }
    const maxSeats = Number(org.get("maxSeats") ?? 5);
    const membersQuery = orgRef.collection("members").where("status", "==", "active");
    const members = await tx.get(membersQuery);
    if (members.size >= maxSeats && !members.docs.some((doc) => doc.id === uid)) {
      throw new HttpsError("resource-exhausted", "Organisation complète.");
    }
    if (members.docs.some((doc) => doc.id === uid)) {
      throw new HttpsError("already-exists", "Votre compte est déjà membre. Connectez-vous sans code.");
    }
    const role = String(invite.get("role") ?? "REP").toUpperCase();
    if (!["REP", "MANAGER"].includes(role)) throw new HttpsError("failed-precondition", "Rôle d’invitation invalide.");
    tx.set(orgRef.collection("members").doc(uid), {
      uid,
      email,
      role,
      status: "active",
      routeAutonomy: true,
      firstName: invite.get("firstName") ?? "",
      lastName: invite.get("lastName") ?? "",
      displayName: `${invite.get("firstName") ?? ""} ${invite.get("lastName") ?? ""}`.trim(),
      managerUid: role === "REP" ? invite.get("managerUid") ?? "" : "",
      joinedAt: FieldValue.serverTimestamp(),
      lastActivityAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(userRef, {
      currentOrgId: orgId,
      currentOrgName: String(org.get("name") ?? "Organisation"),
      currentRole: role,
      currentOrgType: "team",
      orgId,
      orgName: String(org.get("name") ?? "Organisation"),
      role,
      teamOrgId: orgId,
      teamOrgName: String(org.get("name") ?? "Organisation"),
      teamRole: role,
      orgIds: FieldValue.arrayUnion(orgId),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(orgRef.collection("activity").doc(), activityData(
      request,
      "member_joined",
      `${email || "Un membre"} a rejoint l’entreprise en tant que ${role === "MANAGER" ? "responsable commercial" : "commercial"}.`,
      uid,
    ));
    tx.update(inviteRef, {active: false, acceptedBy: uid, acceptedAt: FieldValue.serverTimestamp()});
    tx.update(lookupRef, {active: false, acceptedBy: uid, acceptedAt: FieldValue.serverTimestamp()});
    response = {orgId, orgName: String(org.get("name") ?? "Organisation"), role};
  });
  return response;
});

export const removeOrgMember = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Membre", 128);
  if (memberUid === uid) throw new HttpsError("failed-precondition", "Vous ne pouvez pas vous retirer ici.");
  const role = await memberRole(appId, orgId, uid);
  if (role !== "OWNER") {
    throw new HttpsError("permission-denied", "Droits insuffisants.");
  }
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const targetRef = orgRef.collection("members").doc(memberUid);
  const target = await targetRef.get();
  if (!target.exists) return {removed: true};
  const targetRole = String(target.get("role") ?? "").toUpperCase();
  if (targetRole === "OWNER") {
    throw new HttpsError("failed-precondition", "Le propriétaire ne peut pas être supprimé.");
  }
  const pending = await orgRef.collection("invites").where("email", "==", String(target.get("email") ?? "")).where("active", "==", true).get();
  const userRef = db.collection("users").doc(memberUid);
  const user = await userRef.get();
  const batch = db.batch();
  for (const invitation of pending.docs) {
    batch.update(invitation.ref, {active: false, revokedBy: uid, revokedAt: FieldValue.serverTimestamp()});
    batch.set(appPath(appId).collection("inviteCodes").doc(invitation.id), {active: false, revokedBy: uid, revokedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
  batch.update(targetRef, {status: "removed", removedAt: FieldValue.serverTimestamp(), removedBy: uid});
  const userUpdate: Record<string, unknown> = {
    orgIds: FieldValue.arrayRemove(orgId),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (existingTeamId(user.data() ?? {}) === orgId) {
    userUpdate.teamOrgId = FieldValue.delete();
    userUpdate.teamOrgName = FieldValue.delete();
    userUpdate.teamRole = FieldValue.delete();
  }
  if (String(user.get("orgId") ?? "") === orgId) {
    userUpdate.orgId = FieldValue.delete();
    userUpdate.orgName = FieldValue.delete();
    userUpdate.role = FieldValue.delete();
  }
  if (String(user.get("currentOrgId") ?? "") === orgId) {
    userUpdate.currentOrgId = FieldValue.delete();
    userUpdate.currentOrgName = FieldValue.delete();
    userUpdate.currentRole = FieldValue.delete();
    userUpdate.currentOrgType = "personal";
    userUpdate.orgId = FieldValue.delete();
    userUpdate.orgName = FieldValue.delete();
    userUpdate.role = FieldValue.delete();
  }
  batch.set(userRef, userUpdate, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "member_removed",
    `${String(target.get("email") ?? "Un membre")} a été retiré de l’entreprise.`,
    memberUid,
  ));
  await batch.commit();
  return {removed: true};
});

export const revokeOrgInvite = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const code = requireText(request.data?.code, "Code", 80).toUpperCase();
  const role = await memberRole(appId, orgId, uid);
  if (role !== "OWNER") {
    throw new HttpsError("permission-denied", "Droits insuffisants.");
  }
  const root = appPath(appId);
  const orgRef = root.collection("orgs").doc(orgId);
  const inviteRef = orgRef.collection("invites").doc(code);
  const lookupRef = root.collection("inviteCodes").doc(code);
  const [invitation, lookup] = await Promise.all([inviteRef.get(), lookupRef.get()]);
  if (!invitation.exists || !lookup.exists || lookup.get("orgId") !== orgId) throw new HttpsError("not-found", "Invitation introuvable.");
  const batch = db.batch();
  batch.set(inviteRef, {
    active: false,
    revokedBy: uid,
    revokedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(lookupRef, {
    active: false,
    revokedBy: uid,
    revokedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "invite_revoked",
    "Une invitation a été révoquée.",
  ));
  await batch.commit();
  return {revoked: true};
});

export const updateOrgMemberRole = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Membre", 128);
  const newRole = requireText(request.data?.role, "Rôle", 20).toUpperCase();
  if (!new Set(["REP", "MANAGER"]).has(newRole)) {
    throw new HttpsError("invalid-argument", "Rôle non autorisé.");
  }
  if (await memberRole(appId, orgId, uid) !== "OWNER") {
    throw new HttpsError("permission-denied", "Seul l’administrateur principal peut modifier les rôles.");
  }
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(memberUid);
  const target = await memberRef.get();
  if (!target.exists || target.get("status") !== "active") {
    throw new HttpsError("not-found", "Membre introuvable.");
  }
  if (String(target.get("role") ?? "").toUpperCase() === "OWNER") {
    throw new HttpsError("failed-precondition", "Le rôle du propriétaire ne peut pas être modifié ici.");
  }
  const userRef = db.collection("users").doc(memberUid);
  const user = await userRef.get();
  const batch = db.batch();
  batch.update(memberRef, {
    role: newRole,
    routeAutonomy: newRole === "MANAGER" ? true : false,
    roleUpdatedAt: FieldValue.serverTimestamp(),
    roleUpdatedBy: uid,
  });
  const userUpdate: Record<string, unknown> = {
    teamRole: newRole,
    role: newRole,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (String(user.get("currentOrgId") ?? "") === orgId) {
    userUpdate.currentRole = newRole;
  }
  batch.set(userRef, userUpdate, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "role_changed",
    `${String(target.get("email") ?? "Un membre")} est maintenant ${newRole === "MANAGER" ? "responsable commercial" : "commercial"}.`,
    memberUid,
  ));
  await batch.commit();
  return {updated: true};
});


export const setMemberRouteAutonomy = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  if (await memberRole(appId, orgId, uid) !== "OWNER") throw new HttpsError("permission-denied", "Action réservée à l’administrateur principal.");
  if (request.data?.enabled !== true) throw new HttpsError("failed-precondition", "Chaque commercial peut créer ses propres tournées.");
  return {updated: true, routeAutonomy: true};
});

export const assignMemberPlan = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Commercial", 128);
  const dateId = requireDateId(request.data?.date);
  const prospectIds = stringArray(request.data?.prospectIds, "Prospects", 100);
  const notes = optionalText(request.data?.notes, 1000);
  const replaceExisting = request.data?.replaceExisting === true;
  await requireManagedMember(appId, orgId, uid, memberUid, false);

  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(memberUid);
  const planRef = orgRef.collection("memberData").doc(memberUid).collection("plans").doc(dateId);
  const [target, existing] = await Promise.all([memberRef.get(), planRef.get()]);
  if (!target.exists || target.get("status") !== "active") {
    throw new HttpsError("not-found", "Commercial introuvable ou inactif.");
  }
  if (String(target.get("role") ?? "REP").toUpperCase() !== "REP") {
    throw new HttpsError("failed-precondition", "Une tournée peut être attribuée uniquement à un commercial.");
  }
  if (existing.exists && !replaceExisting) {
    const oldIds = existing.get("prospectIds") as unknown[] | undefined;
    if ((oldIds?.length ?? 0) > 0) {
      throw new HttpsError("already-exists", "Une tournée existe déjà à cette date.");
    }
  }

  const prospectRefs = prospectIds.map((id) => orgRef.collection("prospects").doc(id));
  const prospectSnaps = await db.getAll(...prospectRefs);
  if (prospectSnaps.some((snap) => !snap.exists)) {
    throw new HttpsError("failed-precondition", "Un ou plusieurs prospects ne sont plus disponibles.");
  }

  const date = Timestamp.fromDate(new Date(`${dateId}T12:00:00Z`));
  const email = String(target.get("email") ?? "Le commercial");
  const previousReports = existing.exists && existing.get("reports")
    ? existing.get("reports") as Record<string, unknown>
    : {};
  const preservedReports = Object.fromEntries(
    Object.entries(previousReports).filter(([prospectId]) => prospectIds.includes(prospectId)),
  );
  const batch = db.batch();
  batch.set(planRef, {
    date,
    prospectIds,
    reports: preservedReports,
    orgId,
    ownerUid: memberUid,
    assignedBy: uid,
    assignedByName: String(request.auth?.token.name ?? request.auth?.token.email ?? "Responsable"),
    assignmentSource: "manager",
    assignmentLocked: true,
    assignedAt: FieldValue.serverTimestamp(),
    managerNotes: notes,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "tour_assigned",
    `Une tournée de ${prospectIds.length} prospect(s) a été attribuée à ${email} pour le ${dateId}.`,
    memberUid,
  ));
  await batch.commit();
  await notifyUser(
    memberUid,
    "Nouvelle tournée attribuée",
    `${prospectIds.length} visite(s) prévue(s) le ${dateId}.`,
    {type: "tour_assigned", orgId, date: dateId},
  );
  return {assigned: true, date: dateId, prospectCount: prospectIds.length};
});

export const upsertMemberAppointment = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Commercial", 128);
  const appointmentId = optionalText(request.data?.appointmentId, 128) || db.collection("_ids").doc().id;
  const title = requireText(request.data?.title, "Titre", 180);
  const startsAtText = requireText(request.data?.startsAt, "Date et heure", 64);
  const startsAtDate = new Date(startsAtText);
  if (Number.isNaN(startsAtDate.getTime())) {
    throw new HttpsError("invalid-argument", "Date et heure invalides.");
  }
  const rawDuration = Number(request.data?.durationMinutes ?? 60);
  if (!Number.isFinite(rawDuration)) {
    throw new HttpsError("invalid-argument", "Durée invalide.");
  }
  const durationMinutes = Math.min(480, Math.max(10, Math.round(rawDuration)));
  const prospectId = optionalText(request.data?.prospectId, 128);
  const address = optionalText(request.data?.address, 500);
  const notes = optionalText(request.data?.notes, 1500);
  const forceConflict = request.data?.forceConflict === true;
  await requireManagedMember(appId, orgId, uid, memberUid, true);

  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(memberUid);
  const target = await memberRef.get();
  if (!target.exists || target.get("status") !== "active") {
    throw new HttpsError("not-found", "Commercial introuvable ou inactif.");
  }
  if (String(target.get("role") ?? "REP").toUpperCase() !== "REP") {
    throw new HttpsError("failed-precondition", "Un rendez-vous peut être attribué uniquement à un commercial.");
  }
  if (prospectId) {
    const prospect = await orgRef.collection("prospects").doc(prospectId).get();
    if (!prospect.exists) throw new HttpsError("not-found", "Prospect introuvable.");
  }
  const appointmentsRef = orgRef.collection("memberData").doc(memberUid)
    .collection("appointments");
  const appointmentRef = appointmentsRef.doc(appointmentId);
  const startsAtMs = startsAtDate.getTime();
  const endsAtDate = new Date(startsAtMs + durationMinutes * 60_000);
  const conflictWindowStart = Timestamp.fromDate(new Date(startsAtMs - 480 * 60_000));
  const conflictWindowEnd = Timestamp.fromDate(endsAtDate);
  const [existingAppointment, conflictCandidates] = await Promise.all([
    appointmentRef.get(),
    appointmentsRef
      .where("startsAt", ">=", conflictWindowStart)
      .where("startsAt", "<", conflictWindowEnd)
      .get(),
  ]);
  const conflicting = conflictCandidates.docs.find((doc) => {
    if (doc.id === appointmentId || String(doc.get("status") ?? "scheduled") === "cancelled") return false;
    const otherStartsAt = doc.get("startsAt") as Timestamp | undefined;
    if (!otherStartsAt) return false;
    const otherDuration = Math.min(480, Math.max(10, Number(doc.get("durationMinutes") ?? 60)));
    const otherStartMs = otherStartsAt.toMillis();
    const otherEndMs = otherStartMs + otherDuration * 60_000;
    return otherStartMs < endsAtDate.getTime() && otherEndMs > startsAtMs;
  });
  if (conflicting && !forceConflict) {
    throw new HttpsError(
      "already-exists",
      "Conflit : un autre rendez-vous est déjà prévu sur ce créneau.",
    );
  }

  const email = String(target.get("email") ?? "Le commercial");
  const batch = db.batch();
  batch.set(appointmentRef, {
    title,
    startsAt: Timestamp.fromDate(startsAtDate),
    endsAt: Timestamp.fromDate(endsAtDate),
    durationMinutes,
    prospectId: prospectId || null,
    address,
    notes,
    orgId,
    memberUid,
    assignedBy: uid,
    status: "scheduled",
    ...(existingAppointment.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "appointment_assigned",
    `Rendez-vous « ${title} » ajouté au calendrier de ${email}.`,
    memberUid,
  ));
  await batch.commit();
  await notifyUser(
    memberUid,
    "Nouveau rendez-vous",
    `${title} • ${startsAtDate.toLocaleString("fr-FR")}`,
    {type: "appointment_assigned", orgId, appointmentId},
  );
  return {saved: true, appointmentId};
});

export const cancelMemberAppointment = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Commercial", 128);
  const appointmentId = requireText(request.data?.appointmentId, "Rendez-vous", 128);
  await requireManagedMember(appId, orgId, uid, memberUid, true);
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(memberUid);
  const ref = orgRef.collection("memberData").doc(memberUid).collection("appointments").doc(appointmentId);
  const [member, snap] = await Promise.all([memberRef.get(), ref.get()]);
  if (!member.exists || String(member.get("role") ?? "REP").toUpperCase() !== "REP") {
    throw new HttpsError("not-found", "Commercial introuvable.");
  }
  if (!snap.exists) return {cancelled: true};
  const title = String(snap.get("title") ?? "Rendez-vous");
  const batch = db.batch();
  batch.update(ref, {
    status: "cancelled",
    cancelledBy: uid,
    cancelledAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "appointment_cancelled",
    `Le rendez-vous « ${title} » a été annulé.`,
    memberUid,
  ));
  await batch.commit();
  await notifyUser(memberUid, "Rendez-vous annulé", title, {type: "appointment_cancelled", orgId});
  return {cancelled: true};
});

export const transferOrgOwnership = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const memberUid = requireText(request.data?.memberUid, "Membre", 128);
  if (memberUid === uid) throw new HttpsError("failed-precondition", "Vous êtes déjà propriétaire.");
  if (await memberRole(appId, orgId, uid) !== "OWNER") {
    throw new HttpsError("permission-denied", "Seul le propriétaire peut transférer l’entreprise.");
  }
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const oldRef = orgRef.collection("members").doc(uid);
  const newRef = orgRef.collection("members").doc(memberUid);
  const oldUserRef = db.collection("users").doc(uid);
  const newUserRef = db.collection("users").doc(memberUid);
  await db.runTransaction(async (tx) => {
    const target = await tx.get(newRef);
    if (!target.exists || target.get("status") !== "active") {
      throw new HttpsError("not-found", "Le nouveau propriétaire doit être un membre actif.");
    }
    tx.update(oldRef, {role: "MANAGER", roleUpdatedAt: FieldValue.serverTimestamp()});
    tx.update(newRef, {role: "OWNER", roleUpdatedAt: FieldValue.serverTimestamp()});
    tx.set(oldUserRef, {teamRole: "MANAGER", role: "MANAGER", currentRole: "MANAGER"}, {merge: true});
    tx.set(newUserRef, {teamRole: "OWNER", role: "OWNER", currentRole: "OWNER"}, {merge: true});
    tx.update(orgRef, {createdBy: memberUid, ownerUid: memberUid, updatedAt: FieldValue.serverTimestamp()});
    tx.create(orgRef.collection("activity").doc(), activityData(
      request,
      "ownership_transferred",
      `${String(target.get("email") ?? "Un membre")} est devenu administrateur principal.`,
      memberUid,
    ));
  });
  return {transferred: true};
});

export const leaveOrganization = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const role = await memberRole(appId, orgId, uid);
  if (!role) return {left: true};
  if (role === "OWNER") {
    throw new HttpsError("failed-precondition", "Transférez d’abord la propriété de l’entreprise.");
  }
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const memberRef = orgRef.collection("members").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const batch = db.batch();
  batch.update(memberRef, {
    status: "left",
    leftAt: FieldValue.serverTimestamp(),
  });
  batch.set(userRef, {
    currentOrgType: "personal",
    currentOrgId: FieldValue.delete(),
    currentOrgName: FieldValue.delete(),
    currentRole: FieldValue.delete(),
    teamOrgId: FieldValue.delete(),
    teamOrgName: FieldValue.delete(),
    teamRole: FieldValue.delete(),
    orgId: FieldValue.delete(),
    orgName: FieldValue.delete(),
    role: FieldValue.delete(),
    orgIds: FieldValue.arrayRemove(orgId),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "member_left",
    `${actorEmail(request) || "Un membre"} a quitté l’entreprise.`,
    uid,
  ));
  await batch.commit();
  return {left: true};
});

export const updateOrgProfile = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const name = requireText(request.data?.name, "Nom de l’entreprise", 100);
  if (await memberRole(appId, orgId, uid) !== "OWNER") {
    throw new HttpsError("permission-denied", "Seul l’administrateur principal peut modifier l’identité de l’entreprise.");
  }
  const slogan = optionalText(request.data?.slogan, 100);
  const logoUrl = optionalText(request.data?.logoUrl, 1500);
  const companyEmail = optionalEmail(request.data?.companyEmail);
  const companyPhone = optionalText(request.data?.companyPhone, 40);
  const website = optionalText(request.data?.website, 200);
  const orgRef = appPath(appId).collection("orgs").doc(orgId);
  const members = await orgRef.collection("members").where("status", "==", "active").get();
  const batch = db.batch();
  batch.update(orgRef, {
    name,
    slogan,
    logoUrl,
    companyEmail,
    companyPhone,
    website,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: uid,
  });
  for (const member of members.docs) {
    const userRef = db.collection("users").doc(member.id);
    batch.set(userRef, {
      teamOrgName: name,
      orgName: name,
      currentOrgName: name,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  batch.create(orgRef.collection("activity").doc(), activityData(
    request,
    "organization_updated",
    "L’identité de l’entreprise a été mise à jour.",
  ));
  await batch.commit();
  return {updated: true};
});

export const deleteProspectoAccount = onCall({region, timeoutSeconds: 120}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "appId", 40);
  requireRecentAuthentication(request);

  const userRef = db.collection("users").doc(uid);
  const user = await userRef.get();
  const teamOrgId = existingTeamId(user.data() ?? {});

  if (teamOrgId) {
    const orgRef = appPath(appId).collection("orgs").doc(teamOrgId);
    const memberRef = orgRef.collection("members").doc(uid);
    const member = await memberRef.get();
    const role = String(member.get("role") ?? "").toUpperCase();
    if (member.exists && member.get("status") === "active" && role === "OWNER") {
      throw new HttpsError(
        "failed-precondition",
        "Transférez d’abord la propriété de l’entreprise avant de supprimer votre compte.",
      );
    }

    if (member.exists && member.get("status") === "active") {
      const batch = db.batch();
      batch.update(memberRef, {
        status: "account-deleted",
        leftAt: FieldValue.serverTimestamp(),
      });
      batch.create(orgRef.collection("activity").doc(), activityData(
        request,
        "member_account_deleted",
        `${actorEmail(request) || "Un membre"} a supprimé son compte Prospecto.`,
        uid,
      ));
      await batch.commit();
    }
  }

  try {
    await getStorage().bucket().deleteFiles({prefix: `users/${uid}/`});
  } catch (error) {
    console.error("Personal storage cleanup failed", uid, error);
  }

  // Supprime le profil ainsi que toutes ses sous-collections personnelles
  // (prospects, tournées, rappels et compteurs).
  await db.recursiveDelete(userRef);
  await getAuth().deleteUser(uid);
  return {deleted: true};
});

export const verifyGooglePlayPurchase = onCall({region, timeoutSeconds: 60}, async (request) => {
  const uid = requireUser(request);
  const productId = requireText(request.data?.productId, "Produit", 100);
  const purchaseToken = requireText(request.data?.purchaseToken, "Jeton d’achat", 5000);
  if (!allowedProducts.has(productId)) {
    throw new HttpsError("invalid-argument", "Produit Premium inconnu.");
  }
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({version: "v3", auth});
  let purchase;
  try {
    const response = await publisher.purchases.subscriptionsv2.get({packageName, token: purchaseToken});
    purchase = response.data;
  } catch (error) {
    console.error("Google Play verification failed", error);
    throw new HttpsError("permission-denied", "Achat non reconnu par Google Play.");
  }
  const state = String(purchase.subscriptionState ?? "");
  const lineItems = purchase.lineItems ?? [];
  const verifiedProduct = lineItems.some((item) => item.productId === productId);
  if (!verifiedProduct) throw new HttpsError("permission-denied", "Le produit acheté ne correspond pas.");
  const expiryMs = Math.max(0, ...lineItems.map((item) => Date.parse(String(item.expiryTime ?? ""))).filter(Number.isFinite));
  const validStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  const active = validStates.has(state) && expiryMs > Date.now();
  if (!active) throw new HttpsError("failed-precondition", "L’abonnement n’est pas actif.");

  const tokenHash = createHash("sha256").update(purchaseToken).digest("hex");
  const tokenRef = db.collection("playPurchaseTokens").doc(tokenHash);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(tokenRef);
    if (existing.exists && existing.get("uid") !== uid) {
      throw new HttpsError("already-exists", "Cet achat est déjà associé à un autre compte.");
    }
    tx.set(tokenRef, {
      uid, productId, packageName, state,
      purchaseToken,
      active: true,
      expiryAt: Timestamp.fromMillis(expiryMs),
      checkedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(userRef, {
      entitlements: {
        isPremium: true,
        activePlan: productId === "premium_yearly" ? "PREMIUM_YEARLY" : "PREMIUM_MONTHLY",
        productId,
        premiumUntil: Timestamp.fromMillis(expiryMs),
        purchaseTokenHash: tokenHash,
        verifiedAt: FieldValue.serverTimestamp(),
        subscriptionState: state,
      },
    }, {merge: true});
  });

  if (purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING") {
    try {
      await publisher.purchases.subscriptions.acknowledge({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
        requestBody: {},
      });
    } catch (error) {
      // Le droit est vérifié. Une nouvelle restauration retentera l'accusé réception.
      console.error("Subscription acknowledgement failed", error);
    }
  }
  return {delivered: true, active: true, productId, premiumUntil: new Date(expiryMs).toISOString()};
});

export const syncGooglePlaySubscriptions = onSchedule({
  region,
  schedule: "every 6 hours",
  timeZone: "Europe/Paris",
  timeoutSeconds: 300,
}, async () => {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({version: "v3", auth});
  const tokens = await db.collection("playPurchaseTokens")
    .where("active", "==", true)
    .limit(200)
    .get();
  for (const tokenDoc of tokens.docs) {
    const token = String(tokenDoc.get("purchaseToken") ?? "");
    const uid = String(tokenDoc.get("uid") ?? "");
    if (!token || !uid) continue;
    try {
      const response = await publisher.purchases.subscriptionsv2.get({packageName, token});
      const purchase = response.data;
      const state = String(purchase.subscriptionState ?? "");
      const expiryMs = Math.max(0, ...(purchase.lineItems ?? [])
        .map((item) => Date.parse(String(item.expiryTime ?? "")))
        .filter(Number.isFinite));
      const activeStates = new Set([
        "SUBSCRIPTION_STATE_ACTIVE",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
        "SUBSCRIPTION_STATE_CANCELED",
      ]);
      const active = activeStates.has(state) && expiryMs > Date.now();
      const batch = db.batch();
      batch.set(tokenDoc.ref, {
        state, active,
        expiryAt: expiryMs > 0 ? Timestamp.fromMillis(expiryMs) : null,
        checkedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      const userRef = db.collection("users").doc(uid);
      const user = await userRef.get();
      if (user.get("entitlements.purchaseTokenHash") === tokenDoc.id) {
        batch.set(userRef, {entitlements: {
          isPremium: active,
          activePlan: active ? user.get("entitlements.activePlan") ?? "PREMIUM" : "FREE",
          productId: tokenDoc.get("productId"),
          premiumUntil: expiryMs > 0 ? Timestamp.fromMillis(expiryMs) : null,
          purchaseTokenHash: tokenDoc.id,
          subscriptionState: state,
          verifiedAt: FieldValue.serverTimestamp(),
        }}, {merge: true});
      }
      await batch.commit();
    } catch (error) {
      console.error("Subscription synchronization failed", tokenDoc.id, error);
    }
  }
});

export const sendDueFollowUpReminders = onSchedule({
  region,
  schedule: "every 5 minutes",
  timeZone: "Europe/Paris",
  timeoutSeconds: 120,
}, async () => {
  const now = Timestamp.now();
  const snapshot = await db.collectionGroup("reminders")
    .where("status", "==", "pending")
    .where("dueAt", "<=", now)
    .orderBy("dueAt")
    .limit(200)
    .get();

  for (const reminder of snapshot.docs) {
    const uid = reminder.ref.parent.parent?.id;
    if (!uid) continue;
    const user = await db.collection("users").doc(uid).get();
    if (user.get("notificationsEnabled") === false) {
      await reminder.ref.update({status: "muted", processedAt: FieldValue.serverTimestamp()});
      continue;
    }
    // A revoked employee must not receive reminders containing enterprise data.
    const segments = reminder.ref.path.split("/");
    if (segments[0] === "apps" && segments[2] === "orgs" &&
        !await memberRole(segments[1], segments[3], uid)) {
      await reminder.ref.update({status: "access-revoked", processedAt: FieldValue.serverTimestamp()});
      continue;
    }
    const tokensMap = user.get("fcmTokens") as Record<string, unknown> | undefined;
    const tokens = Object.keys(tokensMap ?? {}).slice(0, 100);
    if (tokens.length === 0) {
      await reminder.ref.update({status: "no-device", processedAt: FieldValue.serverTimestamp()});
      continue;
    }
    const name = String(reminder.get("prospectName") ?? "votre prospect");
    const address = String(reminder.get("address") ?? "");
    const kind = String(reminder.get("kind") ?? "1h");
    const title = kind === "24h" ? "Relance prévue demain" : "Relance dans une heure";
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body: `${name}${address ? ` • ${address}` : ""}`},
      data: {
        type: "follow_up",
        prospectId: String(reminder.get("prospectId") ?? ""),
      },
      android: {priority: "high", notification: {channelId: "prospecto_reminders"}},
    });
    const updates: Record<string, unknown> = {
      status: result.successCount > 0 ? "sent" : "failed",
      successCount: result.successCount,
      failureCount: result.failureCount,
      processedAt: FieldValue.serverTimestamp(),
    };
    await reminder.ref.update(updates);
    const invalidTokens: string[] = [];
    result.responses.forEach((response, index) => {
      const code = response.error?.code ?? "";
      if (code.includes("registration-token-not-registered") || code.includes("invalid-registration-token")) {
        invalidTokens.push(tokens[index]);
      }
    });
    if (invalidTokens.length > 0) {
      const removals: Record<string, unknown> = {};
      for (const token of invalidTokens) removals[`fcmTokens.${token}`] = FieldValue.delete();
      await user.ref.update(removals);
    }
  }
});

// Cycle de vente séparé des rapports de visite ; écritures exclusivement serveur.
export const saveSalesOpportunity = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "Application", 40);
  const personal = request.data?.workspace === "personal";
  if (request.data?.workspace != null && !["personal", "team"].includes(request.data.workspace)) throw new HttpsError("invalid-argument", "Espace invalide.");
  const orgId = personal ? "" : requireText(request.data?.orgId, "Organisation", 100);
  if (personal && request.data?.orgId) throw new HttpsError("invalid-argument", "Une vente Solo ne peut pas cibler une entreprise.");
  const prospectId = requireText(request.data?.prospectId, "Prospect", 200);
  const opportunityId = requireText(request.data?.opportunityId, "Opportunité", 100);
  if ([appId, orgId, prospectId, opportunityId].some((v) => v.includes("/"))) throw new HttpsError("invalid-argument", "Identifiant invalide");
  let values: ReturnType<typeof salesPayload>;
  try { values = salesPayload(request.data, Date.now()); }
  catch (e) { throw new HttpsError("invalid-argument", (e as Error).message); }
  const org = personal ? db.collection("users").doc(uid) : appPath(appId).collection("orgs").doc(orgId);
  const ref = (personal ? org : org.collection("memberData").doc(uid)).collection("opportunities").doc(opportunityId);
  return db.runTransaction(async (tx) => {
    const [orgSnap, member, prospect, existing] = await Promise.all([
      tx.get(org), personal ? Promise.resolve(null) : tx.get(org.collection("members").doc(uid)),
      tx.get(org.collection("prospects").doc(prospectId)), tx.get(ref),
    ]);
    if (!personal && (!orgSnap.exists || !subscriptionIsActive(orgSnap.data() ?? {}) || member?.get("status") !== "active" || member?.get("role") !== "REP")) throw new HttpsError("permission-denied", "Réservé à un commercial actif.");
    if (existing.get("deletedAt")) throw new HttpsError("failed-precondition", "Cette opportunité a été supprimée par l’administrateur.");
    if (!prospect.exists) throw new HttpsError("not-found", "Le prospect n’existe plus.");
    if (existing.exists && existing.get("prospectId") !== prospectId) throw new HttpsError("invalid-argument", "Le prospect d’une opportunité ne peut pas changer.");
    const mutationHash = createHash('sha256').update(JSON.stringify(values)).digest('hex');
    if (existing.exists && existing.get('revision') === Number(request.data?.expectedRevision) + 1 && existing.get('lastMutationHash') === mutationHash) return {opportunityId, revision: existing.get('revision')};
    try { assertSalesRevision(existing.exists ? Number(existing.get("revision")) : null, request.data?.expectedRevision); }
    catch { throw new HttpsError("aborted", "L’opportunité a changé. Actualisez avant de réessayer ; votre brouillon est conservé."); }
    const previous = existing.data() ?? {};
    if (existing.exists && needsSalesCorrection({...previous, signedAtMs: previous.signedAt?.toMillis?.() ?? null}, values) && !values.correctionReason) throw new HttpsError("failed-precondition", "Précisez le motif de correction d’une affaire clôturée.");
    const revision = existing.exists ? Number(existing.get("revision")) + 1 : 1;
    const terminal = ["won", "lost"].includes(values.stage);
    const closedAt = values.stage === "won" ? Timestamp.fromMillis(values.signedAtMs!)
      : values.stage === "lost" ? (previous.stage === "lost" ? previous.closedAt : Timestamp.now()) : null;
    const next = {
      ...values, signedAtMs: undefined, nextActionAtMs: undefined, correctionReason: undefined,
      lastMutationHash: mutationHash, ownerUid: uid, orgId, prospectId, prospectName: prospect.get("name") ?? "Prospect",
      revision, signedAt: values.signedAtMs === null ? null : Timestamp.fromMillis(values.signedAtMs),
      nextActionAt: values.nextActionAtMs === null ? null : Timestamp.fromMillis(values.nextActionAtMs),
      closedAt: terminal ? closedAt : null,
      createdAt: previous.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    };
    delete next.signedAtMs; delete next.nextActionAtMs; delete next.correctionReason;
    tx.set(ref, next);
    const beforeAudit = {...previous}; delete beforeAudit.lastMutationHash;
    const afterAudit = {...next}; delete (afterAudit as Partial<typeof next>).lastMutationHash;
    tx.create(ref.collection("history").doc(String(revision)), {
      revision, actorUid: uid, at: FieldValue.serverTimestamp(),
      before: existing.exists ? beforeAudit : null,
      after: afterAudit,
      correctionReason: values.correctionReason,
    });
    return {opportunityId, revision};
  });
});

// Remplacement atomique de l'équipe d'un responsable : aucun transfert partiel.
export const assignManagerTeam = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "Application", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const managerUid = requireText(request.data?.managerUid, "Responsable", 128);
  if (appId.includes("/") || orgId.includes("/") || managerUid.includes("/")) throw new HttpsError("invalid-argument", "Identifiant invalide.");
  const raw = request.data?.memberUids;
  if (!Array.isArray(raw) || raw.length > 100 || raw.some((v: unknown) => typeof v !== "string" || !v || (v as string).includes("/") || (v as string).length > 128)) throw new HttpsError("invalid-argument", "Sélection de 100 commerciaux maximum.");
  const selected = [...new Set<string>(raw)];
  const org = appPath(appId).collection("orgs").doc(orgId);
  const members = org.collection("members");
  return db.runTransaction(async (tx) => {
    const [organization, actor, manager, assigned] = await Promise.all([
      tx.get(org), tx.get(members.doc(uid)), tx.get(members.doc(managerUid)),
      tx.get(members.where("managerUid", "==", managerUid).where("role", "==", "REP")),
    ]);
    if (!organization.exists || !subscriptionIsActive(organization.data() ?? {}) || actor.get("status") !== "active" || actor.get("role") !== "OWNER") throw new HttpsError("permission-denied", "Réservé à l’administrateur principal.");
    if (manager.get("status") !== "active" || manager.get("role") !== "MANAGER") throw new HttpsError("failed-precondition", "Responsable inactif.");
    if (assigned.size > 200) throw new HttpsError("resource-exhausted", "Équipe trop grande pour cette opération ; contactez le support.");
    const chosen = await Promise.all(selected.map((id) => tx.get(members.doc(id))));
    if (chosen.some((d) => !d.exists || d.get("role") !== "REP" || d.get("status") !== "active")) throw new HttpsError("failed-precondition", "Un commercial de la sélection n’est plus actif. Actualisez.");
    for (const doc of assigned.docs) if (!selected.includes(doc.id)) tx.update(doc.ref, {managerUid: "", updatedAt: FieldValue.serverTimestamp()});
    for (const doc of chosen) if (doc.get("managerUid") !== managerUid) tx.update(doc.ref, {managerUid, updatedAt: FieldValue.serverTimestamp()});
    tx.create(org.collection("activity").doc(), {action: "team_assigned", message: `Équipe mise à jour : ${selected.length} commerciaux.`, actorUid: uid, targetUid: managerUid, createdAt: FieldValue.serverTimestamp()});
    return {updated: true, count: selected.length};
  });
});

// Company-owned presentation settings, shared by every administrative/field view.
export const updateEnterpriseDisplaySettings = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "Application", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  if (orgId.includes("/")) throw new HttpsError("invalid-argument", "Identifiant invalide.");
  const showContracts = request.data?.showContracts;
  const showRevenue = request.data?.showRevenue;
  if (typeof showContracts !== "boolean" || typeof showRevenue !== "boolean" || (!showContracts && !showRevenue)) {
    throw new HttpsError("invalid-argument", "Choisissez au moins un indicateur commercial.");
  }
  const org = appPath(appId).collection("orgs").doc(orgId);
  await db.runTransaction(async (tx) => {
    const [organization, actor] = await Promise.all([tx.get(org), tx.get(org.collection("members").doc(uid))]);
    if (!organization.exists || !subscriptionIsActive(organization.data() ?? {}) || actor.get("role") !== "OWNER" || actor.get("status") !== "active") {
      throw new HttpsError("permission-denied", "Réservé à l’administrateur principal.");
    }
    tx.update(org, {displaySettings: {showContracts, showRevenue}, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid});
    tx.create(org.collection("activity").doc(), activityData(request, "display_settings_updated", "Les indicateurs commerciaux ont été configurés."));
  });
  return {updated: true};
});

// Delete a directory entry or remove an opportunity from live results.
// Historical route reports and the immutable opportunity audit are preserved.
export const deleteEnterpriseRecord = onCall({region}, async (request) => {
  const uid = requireUser(request);
  const appId = requireText(request.data?.appId, "Application", 40);
  const orgId = requireText(request.data?.orgId, "Organisation", 100);
  const id = requireText(request.data?.id, "Fiche", 200);
  const kind = request.data?.kind;
  const ownerUid = kind === "opportunity" ? requireText(request.data?.ownerUid, "Commercial", 128) : "";
  if (!["prospect", "opportunity"].includes(kind) || [orgId, id, ownerUid].some(v => v.includes("/"))) {
    throw new HttpsError("invalid-argument", "Fiche invalide.");
  }
  const org = appPath(appId).collection("orgs").doc(orgId);
  const ref = kind === "prospect" ? org.collection("prospects").doc(id)
    : org.collection("memberData").doc(ownerUid).collection("opportunities").doc(id);
  return db.runTransaction(async (tx) => {
    const [organization, actor, target] = await Promise.all([tx.get(org), tx.get(org.collection("members").doc(uid)), tx.get(ref)]);
    if (!organization.exists || !subscriptionIsActive(organization.data() ?? {}) || actor.get("role") !== "OWNER" || actor.get("status") !== "active") {
      throw new HttpsError("permission-denied", "Réservé à l’administrateur principal.");
    }
    if (!target.exists) throw new HttpsError("not-found", "Cette fiche n’existe plus.");
    if (target.get("deletedAt")) return {deleted: true};
    const deletedAt = FieldValue.serverTimestamp();
    if (kind === "prospect") {
      tx.create(org.collection("deletedRecords").doc(), {kind, originalPath: ref.path, data: target.data(), deletedBy: uid, deletedAt});
      tx.delete(ref);
    } else {
      const revision = Number(target.get("revision") ?? 0) + 1;
      const after = {...target.data(), deletedAt, deletedBy: uid, revision, updatedAt: deletedAt};
      tx.update(ref, {deletedAt, deletedBy: uid, revision, updatedAt: deletedAt});
      tx.create(ref.collection("history").doc(String(revision)), {revision, actorUid: uid, at: deletedAt, before: target.data(), after, correctionReason: "Suppression administrative", action: "deleted"});
    }
    tx.create(org.collection("activity").doc(), activityData(request, `${kind}_deleted`, kind === "prospect" ? "Une fiche prospect a été supprimée du répertoire." : "Une opportunité a été retirée des résultats.", ownerUid || undefined));
    return {deleted: true};
  });
});
