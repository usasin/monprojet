/** Pure validation; Firestore timestamps and identity are added only by the server. */
export const salesStages = ["qualify", "qualified", "proposal", "negotiation", "won", "lost"] as const;
export function salesPayload(raw: Record<string, unknown>, nowMs: number) {
  const text = (key: string, max: number, required = false): string => {
    const value = typeof raw[key] === "string" ? (raw[key] as string).trim() : "";
    if ((required && !value) || value.length > max) throw new Error(`${key}: valeur invalide`);
    return value;
  };
  const stage = text("stage", 20, true);
  if (!(salesStages as readonly string[]).includes(stage)) throw new Error("Étape invalide");
  const interest = text("interest", 12, true);
  if (!["cold", "warm", "hot"].includes(interest)) throw new Error("Intérêt invalide");
  const action = text("nextAction", 16);
  if (!["", "call", "visit", "proposal", "followup"].includes(action)) throw new Error("Action invalide");
  const amountCents = raw.amountCents == null ? null : raw.amountCents;
  if (amountCents !== null && (typeof amountCents !== "number" || !Number.isSafeInteger(amountCents) || amountCents < 0 || amountCents > 100000000000)) throw new Error("Montant HT invalide");
  const date = (key: string): number | null => {
    const v = raw[key];
    if (v === null || v === undefined) return null;
    if (typeof v !== "number" || !Number.isSafeInteger(v) || v < Date.UTC(2000, 0, 1) || v > nowMs + 10 * 366 * 86400000) throw new Error(`${key}: date invalide`);
    return v;
  };
  const signedAtMs = date("signedAtMs");
  const nextActionAtMs = date("nextActionAtMs");
  if (stage === "won" && (signedAtMs === null || signedAtMs > nowMs)) throw new Error("Date de signature passée ou présente obligatoire");
  if (Boolean(action) !== (nextActionAtMs !== null)) throw new Error("Action et échéance doivent être renseignées ensemble");
  const offer = text("offer", 160, stage === "won");
  const lostReason = text("lostReason", 500, stage === "lost");
  return {
    title: text("title", 160, true), stage, interest, amountCents, currency: "EUR",
    offer, contractReference: text("contractReference", 120), lostReason,
    note: text("note", 3000), correctionReason: text("correctionReason", 500),
    nextAction: stage === "won" || stage === "lost" ? "" : action,
    nextActionAtMs: stage === "won" || stage === "lost" ? null : nextActionAtMs,
    signedAtMs: stage === "won" ? signedAtMs : null,
  };
}
export function assertSalesRevision(actual: number | null, expected: unknown): void {
  if (!Number.isInteger(expected) || (actual === null ? expected !== 0 : actual !== expected)) throw new Error("CONFLICT");
}
export function needsSalesCorrection(previous: Record<string, unknown>, next: ReturnType<typeof salesPayload>): boolean {
  return ["won", "lost"].includes(String(previous.stage)) &&
    (previous.stage !== next.stage || previous.amountCents !== next.amountCents || previous.offer !== next.offer || previous.contractReference !== next.contractReference || previous.signedAtMs !== next.signedAtMs);
}
