import {randomBytes} from 'node:crypto';
import {getApps, initializeApp, applicationDefault} from 'firebase-admin/app';
import {Timestamp, getFirestore} from 'firebase-admin/firestore';

const plans = {
  ESSENTIAL: {label: 'Essentiel', seats: 3},
  TEAM: {label: 'Équipe', seats: 10},
  BUSINESS: {label: 'Business', seats: 25},
};

function positiveInt(raw, fallback, label) {
  if (raw == null || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${label} doit être un entier positif.`);
  }
  return value;
}

const [planRaw = 'TEAM', seatsRaw = '', codeDaysRaw = '90', subscriptionDaysRaw = '365', requestedCode] = process.argv.slice(2);
const plan = planRaw.trim().toUpperCase();
const planConfig = plans[plan];
if (!planConfig) {
  throw new Error('Plan invalide. Utilisez ESSENTIAL, TEAM ou BUSINESS.');
}
const maxSeats = positiveInt(seatsRaw, planConfig.seats, 'Le nombre de places');
const codeValidityDays = positiveInt(codeDaysRaw, 90, 'La validité du code');
const subscriptionDays = positiveInt(subscriptionDaysRaw, 365, 'La durée de l’abonnement');
const code = (requestedCode?.trim() || `PRO-${randomBytes(4).toString('hex')}`).toUpperCase();

if (!/^[A-Z0-9_-]{6,80}$/.test(code)) {
  throw new Error('Le code doit contenir 6 à 80 caractères : lettres, chiffres, tiret ou underscore.');
}

if (getApps().length === 0) {
  initializeApp({credential: applicationDefault()});
}

const now = Date.now();
const db = getFirestore();
const ref = db.collection('apps').doc('prospecto').collection('activationCodes').doc(code);
const existing = await ref.get();
if (existing.exists && existing.get('used') === true) {
  throw new Error(`Le code ${code} a déjà été utilisé.`);
}

await ref.set({
  active: true,
  used: false,
  plan,
  planLabel: planConfig.label,
  maxSeats,
  source: 'manual',
  createdAt: Timestamp.fromMillis(now),
  updatedAt: Timestamp.fromMillis(now),
  expiresAt: Timestamp.fromMillis(now + codeValidityDays * 24 * 60 * 60 * 1000),
  subscriptionUntil: Timestamp.fromMillis(now + subscriptionDays * 24 * 60 * 60 * 1000),
}, {merge: true});

console.log(`Code créé : ${code}`);
console.log(`Plan : ${planConfig.label}`);
console.log(`Places : ${maxSeats}`);
console.log(`Code valable : ${codeValidityDays} jours`);
console.log(`Abonnement : ${subscriptionDays} jours`);
