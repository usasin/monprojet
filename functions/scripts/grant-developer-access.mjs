import {applicationDefault, getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

const [emailRaw, actionRaw = 'grant'] = process.argv.slice(2);
const email = (emailRaw || '').trim().toLowerCase();
const action = actionRaw.trim().toLowerCase();

if (!email || !email.includes('@')) {
  throw new Error('Utilisation : node scripts/grant-developer-access.mjs adresse@email.fr [grant|revoke]');
}
if (!['grant', 'revoke'].includes(action)) {
  throw new Error('Action invalide. Utilisez grant ou revoke.');
}
if (getApps().length === 0) {
  initializeApp({credential: applicationDefault()});
}

const auth = getAuth();
const user = await auth.getUserByEmail(email);
const claims = {...(user.customClaims || {})};
if (action === 'grant') {
  claims.prospectoDeveloper = true;
} else {
  delete claims.prospectoDeveloper;
}
await auth.setCustomUserClaims(user.uid, claims);
console.log(`${action === 'grant' ? 'Accès développeur accordé' : 'Accès développeur retiré'} : ${email}`);
console.log('Déconnectez puis reconnectez le compte dans Prospecto pour actualiser les droits.');
