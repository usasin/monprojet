// Run only with a local demo-project emulator. Never uses production Firestore.
if (!process.env.FIRESTORE_EMULATOR_HOST || !String(process.env.GCLOUD_PROJECT).startsWith('demo-')) throw Error('Demo Firestore emulator required');
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {getFirestore} = require('firebase-admin/firestore');
const {doc,getDoc,setDoc,collection,getDocs,query,where,deleteDoc,orderBy,documentId,limit} = require('firebase/firestore');
const fs=require('node:fs');const path=require('node:path');
const {saveSalesOpportunity,assignManagerTeam}=require('../lib');
let env,db;const projectId=process.env.GCLOUD_PROJECT;
const orgPath='apps/prospecto/orgs/test-org';
const payload={appId:'prospecto',orgId:'test-org',prospectId:'p1',opportunityId:'deal1',expectedRevision:0,title:'Contrat test',stage:'won',interest:'hot',offer:'Offre énergie',amountCents:12345,signedAtMs:Date.now()-1000,nextAction:'',nextActionAtMs:null};
const call=(fn,uid,data)=>fn.run({auth:{uid,token:{email:uid+'@example.test'}},data});
before(async()=>{
 const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
 env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
 db=getFirestore();
 await db.doc(orgPath).set({name:'Test',status:'active'});
 for(const [id,role,managerUid,status] of [['owner','OWNER','','active'],['m1','MANAGER','','active'],['m2','MANAGER','','active'],['r1','REP','m1','active'],['r2','REP','m2','active'],['revoked','REP','m1','revoked']]) await db.doc(orgPath+'/members/'+id).set({role,managerUid,status});
 await db.doc(orgPath+'/prospects/p1').set({name:'Client test'});
});
after(async()=>{await env?.cleanup();});
test('commercial records a signed opportunity and immutable history',async()=>{
 const result=await call(saveSalesOpportunity,'r1',payload);assert.equal(result.revision,1);
 const d=await db.doc(orgPath+'/memberData/r1/opportunities/deal1').get();assert.equal(d.get('amountCents'),12345);assert.equal(d.get('ownerUid'),'r1');
 assert.equal((await d.ref.collection('history').get()).size,1);
});
test('retry of an acknowledged-lost request does not duplicate a contract',async()=>{
 const result=await call(saveSalesOpportunity,'r1',payload);assert.equal(result.revision,1);assert.equal((await db.doc(orgPath+'/memberData/r1/opportunities/deal1').collection('history').get()).size,1);
});
test('rep cannot create for a colleague; target identity comes from auth',async()=>{
 await call(saveSalesOpportunity,'r2',{...payload,opportunityId:'own2',ownerUid:'r1'});assert.equal((await db.doc(orgPath+'/memberData/r2/opportunities/own2').get()).get('ownerUid'),'r2');
});
test('manager and revoked user cannot declare sales',async()=>{
 await assert.rejects(call(saveSalesOpportunity,'m1',payload),e=>e.code==='permission-denied');await assert.rejects(call(saveSalesOpportunity,'revoked',payload),e=>e.code==='permission-denied');
});
test('owner and manager can read only authorized scope',async()=>{
 const p=orgPath+'/memberData/r1/opportunities/deal1';
 for(const uid of ['owner','m1','r1']) await assertSucceeds(getDoc(doc(env.authenticatedContext(uid).firestore(),p)));
 for(const uid of ['m2','r2','revoked'])await assertFails(getDoc(doc(env.authenticatedContext(uid).firestore(),p)));
});
test('mobile direct writes to contract and audit are refused',async()=>{
 for(const uid of ['owner','m1','r1']){
  const client=env.authenticatedContext(uid).firestore();
  await assertFails(setDoc(doc(client,orgPath+'/memberData/r1/opportunities/forged'),{stage:'won'}));
  await assertFails(setDoc(doc(client,orgPath+'/memberData/r1/opportunities/deal1/history/forged'),{revision:42}));
 }
});
test('stale revision is rejected and original amount retained',async()=>{
 await assert.rejects(call(saveSalesOpportunity,'r1',{...payload,amountCents:100,expectedRevision:0}),e=>e.code==='aborted');assert.equal((await db.doc(orgPath+'/memberData/r1/opportunities/deal1').get()).get('amountCents'),12345);
});
test('correcting a signed deal requires reason and adds history',async()=>{
 await assert.rejects(call(saveSalesOpportunity,'r1',{...payload,amountCents:100,expectedRevision:1}),e=>e.code==='failed-precondition');
 const result=await call(saveSalesOpportunity,'r1',{...payload,amountCents:100,expectedRevision:1,correctionReason:'Correction du montant'});assert.equal(result.revision,2);assert.equal((await db.doc(orgPath+'/memberData/r1/opportunities/deal1').collection('history').get()).size,2);
});
test('team replacement transfers rights immediately and preserves sale history',async()=>{
 await assert.rejects(call(assignManagerTeam,'m1',{appId:'prospecto',orgId:'test-org',managerUid:'m2',memberUids:['r1']}),e=>e.code==='permission-denied');
 await call(assignManagerTeam,'owner',{appId:'prospecto',orgId:'test-org',managerUid:'m2',memberUids:['r1','r2']});
 const p=orgPath+'/memberData/r1/opportunities/deal1';await assertFails(getDoc(doc(env.authenticatedContext('m1').firestore(),p)));await assertSucceeds(getDoc(doc(env.authenticatedContext('m2').firestore(),p)));
 assert.equal((await db.doc(p).collection('history').get()).size,2);
});
test('invalid team selection causes no partial membership update',async()=>{
 await assert.rejects(call(assignManagerTeam,'owner',{appId:'prospecto',orgId:'test-org',managerUid:'m1',memberUids:['r1','missing']}));assert.equal((await db.doc(orgPath+'/members/r1').get()).get('managerUid'),'m2');
});
test('opportunity query and history honor manager perimeter',async()=>{
 const c=env.authenticatedContext('m2').firestore();await assertSucceeds(getDocs(collection(c,orgPath+'/memberData/r1/opportunities')));await assertSucceeds(getDocs(collection(c,orgPath+'/memberData/r1/opportunities/deal1/history')));
 await assertFails(getDocs(collection(env.authenticatedContext('m1').firestore(),orgPath+'/memberData/r1/opportunities')));
});

test('solo signs a contract in its private scope and preserves enterprise data',async()=>{
 await db.doc('users/solo/prospects/private').set({name:'Client privé'});
 const personal={...payload,workspace:'personal',orgId:undefined,prospectId:'private',opportunityId:'private-sale'};
 const result=await call(saveSalesOpportunity,'solo',personal);assert.equal(result.revision,1);
 const saved=await db.doc('users/solo/opportunities/private-sale').get();
 assert.equal(saved.get('ownerUid'),'solo');assert.equal(saved.get('orgId'),'');
 assert.equal((await saved.ref.collection('history').get()).size,1);
 await assertSucceeds(getDoc(doc(env.authenticatedContext('solo').firestore(),saved.ref.path)));
 await assertFails(getDoc(doc(env.authenticatedContext('owner').firestore(),saved.ref.path)));
 await assertFails(getDoc(doc(env.authenticatedContext('r1').firestore(),saved.ref.path)));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),saved.ref.path)));
});
test('solo sales cannot be forged directly or redirected to a different user',async()=>{
 const client=env.authenticatedContext('solo').firestore();
 await assertFails(setDoc(doc(client,'users/solo/opportunities/forged'),{stage:'won'}));
 await assertFails(setDoc(doc(client,'users/solo/opportunities/private-sale/history/forged'),{revision:99}));
 await assert.rejects(call(saveSalesOpportunity,'other',{...payload,workspace:'personal',orgId:undefined,prospectId:'private'}),e=>e.code==='not-found');
 await assert.rejects(call(saveSalesOpportunity,'solo',{...payload,workspace:'personal'}),e=>e.code==='invalid-argument');
});
test('solo retries and correction use the same revision protection',async()=>{
 const personal={...payload,workspace:'personal',orgId:undefined,prospectId:'private',opportunityId:'private-sale'};
 const result=await call(saveSalesOpportunity,'solo',personal);assert.equal(result.revision,1);
 await assert.rejects(call(saveSalesOpportunity,'solo',{...personal,amountCents:400,expectedRevision:0}),e=>e.code==='aborted');
 await assert.rejects(call(saveSalesOpportunity,'solo',{...personal,amountCents:400,expectedRevision:1}),e=>e.code==='failed-precondition');
 const corrected=await call(saveSalesOpportunity,'solo',{...personal,amountCents:400,expectedRevision:1,correctionReason:'Erreur de saisie'});assert.equal(corrected.revision,2);
 assert.equal((await db.doc('users/solo/opportunities/private-sale/history/2').get()).get('actorUid'),'solo');
});

test('company display configuration is owner-only and validated', async () => {
  const {updateEnterpriseDisplaySettings} = require('../lib');
  const settings = {appId:'prospecto', orgId:'test-org', showContracts:true, showRevenue:false};
  for (const uid of ['m1','r1','revoked']) await assert.rejects(call(updateEnterpriseDisplaySettings,uid,settings), e=>e.code==='permission-denied');
  for (const data of [{...settings,showContracts:false},{...settings,showRevenue:'false'}]) await assert.rejects(call(updateEnterpriseDisplaySettings,'owner',data), e=>e.code==='invalid-argument');
  await call(updateEnterpriseDisplaySettings,'owner',settings);
  assert.deepEqual((await db.doc(orgPath).get()).get('displaySettings'),{showContracts:true,showRevenue:false});
  await assertFails(setDoc(doc(env.authenticatedContext('owner').firestore(),orgPath),{displaySettings:{showRevenue:true}},{merge:true}));
});

test('administrative deletion rejects other roles, other organizations and forged IDs', async () => {
  const {deleteEnterpriseRecord} = require('../lib');
  const data={appId:'prospecto',orgId:'test-org',kind:'prospect',id:'p1'};
  for (const uid of ['m1','r1','revoked']) await assert.rejects(call(deleteEnterpriseRecord,uid,data),e=>e.code==='permission-denied');
  await db.doc('apps/prospecto/orgs/other').set({status:'active'});
  await assert.rejects(call(deleteEnterpriseRecord,'owner',{...data,orgId:'other'}),e=>e.code==='permission-denied');
  await assert.rejects(call(deleteEnterpriseRecord,'owner',{...data,id:'../p1'}),e=>e.code==='invalid-argument');
  await assert.rejects(call(deleteEnterpriseRecord,'owner',{...data,kind:'member'}),e=>e.code==='invalid-argument');
  assert.equal((await db.doc(orgPath+'/prospects/p1').get()).exists,true);
});

test('deleting an opportunity preserves history, increments revision and blocks resurrection', async () => {
  const {deleteEnterpriseRecord} = require('../lib');
  const data={...payload,opportunityId:'deleted-sale'};
  await call(saveSalesOpportunity,'r1',data);
  const ref=db.doc(orgPath+'/memberData/r1/opportunities/deleted-sale');
  const deletion={appId:'prospecto',orgId:'test-org',kind:'opportunity',id:'deleted-sale',ownerUid:'r1'};
  await call(deleteEnterpriseRecord,'owner',deletion);
  assert.equal((await ref.get()).get('deletedBy'),'owner');
  assert.equal((await ref.get()).get('revision'),2);
  assert.equal((await ref.collection('history').get()).size,2);
  await call(deleteEnterpriseRecord,'owner',deletion);
  assert.equal((await ref.collection('history').get()).size,2);
  await assert.rejects(call(saveSalesOpportunity,'r1',{...data,expectedRevision:2}),e=>e.code==='failed-precondition');
});

test('deleting a directory prospect preserves recorded sales and route reports', async () => {
  const {deleteEnterpriseRecord} = require('../lib');
  const p=db.doc(orgPath+'/prospects/remove-me'); await p.set({name:'Archive test'});
  await call(saveSalesOpportunity,'r1',{...payload,prospectId:'remove-me',opportunityId:'retained-sale'});
  const plan=db.doc(orgPath+'/memberData/r1/plans/retained-route');await plan.set({prospectIds:['remove-me'],reports:{'remove-me':{status:'présent'}}});
  await call(deleteEnterpriseRecord,'owner',{appId:'prospecto',orgId:'test-org',kind:'prospect',id:'remove-me'});
  assert.equal((await p.get()).exists,false);
  assert.equal((await db.doc(orgPath+'/memberData/r1/opportunities/retained-sale').get()).get('stage'),'won');
  assert.equal((await plan.get()).get('reports')['remove-me'].status,'présent');
  assert.equal((await db.collection(orgPath+'/deletedRecords').where('originalPath','==',p.path).get()).size,1);
  await assertFails(getDocs(collection(env.authenticatedContext('r1').firestore(),orgPath+'/deletedRecords')));
});

test('deleting an invitation disables both records and prevents acceptance', async () => {
  const {revokeOrgInvite,acceptOrgInvite} = require('../lib');
  const code='DELETIONTESTINVITE';
  await db.doc(orgPath+'/invites/'+code).set({active:true,email:'invitee@example.test',role:'REP',expiresAt:require('firebase-admin/firestore').Timestamp.fromMillis(Date.now()+60000)});
  await db.doc('apps/prospecto/inviteCodes/'+code).set({active:true,orgId:'test-org'});
  await assert.rejects(call(revokeOrgInvite,'r1',{appId:'prospecto',orgId:'test-org',code}),e=>e.code==='permission-denied');
  await call(revokeOrgInvite,'owner',{appId:'prospecto',orgId:'test-org',code});
  for (const path of [orgPath+'/invites/'+code,'apps/prospecto/inviteCodes/'+code]) assert.equal((await db.doc(path).get()).get('active'),false);
  await assert.rejects(call(acceptOrgInvite,'invitee',{appId:'prospecto',code}));
});


test('directory deletion cannot bypass the server archive', async () => {
  for (const uid of ['owner','m2','r1']) await assertFails(deleteDoc(doc(env.authenticatedContext(uid).firestore(),orgPath+'/prospects/p1')));
  assert.equal((await db.doc(orgPath+'/prospects/p1').get()).exists,true);
});

test('manager member pagination is allowed only for its own representatives', async () => {
  const c=env.authenticatedContext('m2').firestore();
  const q=query(collection(c,orgPath+'/members'),where('role','==','REP'),where('managerUid','==','m2'),orderBy(documentId()),limit(200));
  const rows=await assertSucceeds(getDocs(q));
  assert.deepEqual(rows.docs.map(d=>d.id),['r1','r2']);
  await assertFails(getDocs(query(collection(c,orgPath+'/members'),where('role','==','REP'),where('managerUid','==','m1'))));
});
