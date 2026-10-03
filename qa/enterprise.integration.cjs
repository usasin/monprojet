// Local emulator only. Never run this suite against a real Firebase project.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, collection, query, where, setDoc} = require('firebase/firestore');
const {getFirestore} = require('node:module').createRequire(path.join(__dirname, '../functions/package.json'))('firebase-admin/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.GCLOUD_PROJECT?.startsWith('demo-')) throw Error('Local demo emulator required');
const f = require('../functions/lib/index.js');
const projectId = process.env.GCLOUD_PROJECT;
const db = getFirestore();
const base = 'apps/prospecto/orgs/company';
const call = (name, uid, data, email = `${uid}@example.com`, verified = true) => f[name].run({data: {appId: 'prospecto', orgId: 'company', ...data}, auth: {uid, token: {email, email_verified: verified, name: uid, auth_time: Math.floor(Date.now()/1000)}}});
let count = 0;
async function check(name, fn) { await fn(); count++; console.log(`PASS ${name}`); }
(async () => {
 const env = await initializeTestEnvironment({projectId, firestore: {rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8')}});
 try {
  await env.clearFirestore();
  await db.doc(base).set({name:'Test Company',status:'active',maxSeats:25});
  for (const [uid,role,managerUid] of [['owner','OWNER',''],['manager','MANAGER',''],['manager2','MANAGER',''],['rep','REP','manager'],['other','REP','manager2']]) {
   await db.doc(`${base}/members/${uid}`).set({uid,role,managerUid,status:'active',email:`${uid}@example.com`,routeAutonomy:false});
   await db.doc(`users/${uid}`).set({teamOrgId:'company',currentOrgId:'company',currentOrgType:'team'});
   await db.doc(`${base}/memberData/${uid}/plans/2026-10-01`).set({date:new Date('2026-10-01'),prospectIds:['p'],reports:{}});
  }
  await db.doc(`${base}/prospects/p`).set({name:'P'});
  const client = (uid) => env.authenticatedContext(uid).firestore();
  await check('REP own data allowed; colleague data denied', async () => {
   await assertSucceeds(getDoc(doc(client('rep'),`${base}/memberData/rep/plans/2026-10-01`)));
   await assertFails(getDoc(doc(client('rep'),`${base}/memberData/other/plans/2026-10-01`)));
  });
  await check('MANAGER team scope enforced for reads and queries', async () => {
   await assertSucceeds(getDoc(doc(client('manager'),`${base}/memberData/rep/plans/2026-10-01`)));
   await assertFails(getDoc(doc(client('manager'),`${base}/memberData/other/plans/2026-10-01`)));
   await assertSucceeds(getDocs(query(collection(client('manager'),`${base}/members`),where('managerUid','==','manager'),where('role','==','REP'))));
   await assertFails(getDocs(collection(client('manager'),`${base}/members`)));
  });
  await check('REP can create a route even with legacy autonomy=false', async () => {
   await assertSucceeds(setDoc(doc(client('rep'),`${base}/memberData/rep/plans/2026-10-02`),{date:new Date(),prospectIds:['p']}));
  });
  await check('Administration and invitation reads denied to MANAGER/REP', async () => {
   await assertFails(getDocs(collection(client('manager'),`${base}/invites`)));
   await assertFails(setDoc(doc(client('manager'),`${base}/members/new`),{role:'MANAGER',status:'active'}));
   await assertFails(setDoc(doc(client('rep'),'users/rep'),{prospectoDeveloper:true},{merge:true}));
  });
  await check('Only OWNER may create invitations; all identity fields required', async () => {
   await assert.rejects(call('createOrgInvite','manager',{email:'new@example.com',firstName:'New',lastName:'User'}),e=>e.code==='permission-denied');
   await assert.rejects(call('createOrgInvite','owner',{email:'new@example.com',firstName:'New'}),e=>e.code==='invalid-argument');
  });
  const invitation = await call('createOrgInvite','owner',{email:'new@example.com',firstName:'New',lastName:'User',role:'REP',managerUid:'manager'});
  await check('Preview identifies the intended recipient', async () => {
   const preview = await f.previewOrgInvite.run({data:{appId:'prospecto',code:invitation.code}});
   assert.equal(preview.email,'new@example.com');assert.equal(preview.firstName,'New');
  });
  await check('Wrong address and unverified account cannot activate', async () => {
   await assert.rejects(call('acceptOrgInvite','wrong',{code:invitation.code}),e=>e.code==='permission-denied');
   await assert.rejects(call('acceptOrgInvite','new',{code:invitation.code},'new@example.com',false),e=>e.code==='failed-precondition');
  });
  await check('Concurrent activation consumes the code exactly once', async () => {
   const result = await Promise.allSettled([call('acceptOrgInvite','new',{code:invitation.code}),call('acceptOrgInvite','new',{code:invitation.code})]);
   assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
   const member = await db.doc(`${base}/members/new`).get();
   assert.equal(member.get('displayName'),'New User');assert.equal(member.get('managerUid'),'manager');
   assert.equal((await db.doc('users/new').get()).get('teamOrgId'),'company');
  });
  await check('Existing member cannot change their role via another invitation', async () => {
   const other = await call('createOrgInvite','owner',{email:'rep@example.com',firstName:'R',lastName:'P',role:'MANAGER'});
   await assert.rejects(call('acceptOrgInvite','rep',{code:other.code}),e=>e.code==='already-exists');
   assert.equal((await db.doc(`${base}/members/rep`).get()).get('role'),'REP');
  });
  await check('MANAGER cannot revoke or administer members', async () => {
   await assert.rejects(call('removeOrgMember','manager',{memberUid:'rep'}),e=>e.code==='permission-denied');
   await assert.rejects(call('assignMemberManager','manager',{memberUid:'rep',managerUid:'manager2'}),e=>e.code==='permission-denied');
   await assert.rejects(call('revokeOrgInvite','manager',{code:invitation.code}),e=>e.code==='permission-denied');
  });
  await check('MANAGER assigns only within their team; REP creates own appointment', async () => {
   await assert.rejects(call('assignMemberPlan','manager',{memberUid:'other',date:'2026-10-03',prospectIds:['p']}),e=>e.code==='permission-denied');
   await call('assignMemberPlan','manager',{memberUid:'rep',date:'2026-10-03',prospectIds:['p']});
   await call('upsertMemberAppointment','rep',{memberUid:'rep',title:'Self appointment',startsAt:'2026-10-03T10:00:00Z'});
   await assert.rejects(call('upsertMemberAppointment','rep',{memberUid:'other',title:'No',startsAt:'2026-10-03T10:00:00Z'}),e=>e.code==='permission-denied');
  });
  await check('Revocation denies access, clears active link and preserves history', async () => {
   const pending = await call('createOrgInvite','owner',{email:'rep@example.com',firstName:'R',lastName:'P'});
   await call('removeOrgMember','owner',{memberUid:'rep'});
   assert.equal((await db.doc('users/rep').get()).get('teamOrgId'),undefined);
   assert.equal((await db.doc(`${base}/memberData/rep/plans/2026-10-01`).get()).exists,true);
   await assertFails(getDoc(doc(client('rep'),`${base}/memberData/rep/plans/2026-10-01`)));
   await assertSucceeds(getDoc(doc(client('owner'),`${base}/memberData/rep/plans/2026-10-01`)));
   await assert.rejects(call('acceptOrgInvite','rep',{code:pending.code}),e=>e.code==='not-found');
  });
  console.log(`${count} integration scenarios passed`);
 } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
