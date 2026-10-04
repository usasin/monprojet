const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {SignedDataVerifier, Environment} = require('@apple/app-store-server-library');
const {appleAccountToken, appleBundleId, appleProducts, appleSubscriptionKey, validateApplePurchase} = require('../lib/apple_purchase_logic');
const now = Date.UTC(2026, 9, 3, 12);
const valid = () => ({bundleId: appleBundleId, productId: 'premium_monthly', type: 'Auto-Renewable Subscription',
  inAppOwnershipType: 'PURCHASED', environment: 'Production', transactionId: '200000000000001',
  originalTransactionId: '200000000000000', appAccountToken: appleAccountToken('customer-1'),
  purchaseDate: now - 86400000, expiresDate: now + 86400000, signedDate: now});

test('account token is a stable opaque UUID and distinct per Firebase account', () => {
  assert.match(appleAccountToken('customer-1'), /^[a-f0-9]{8}-[a-f0-9]{4}-5[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/);
  assert.equal(appleAccountToken('customer-1'), appleAccountToken('customer-1'));
  assert.notEqual(appleAccountToken('customer-1'), appleAccountToken('customer-2'));
});
test('valid production subscription grants only its signed expiry', () => {
  assert.equal(validateApplePurchase(valid(), 'premium_monthly', 'customer-1', now), now + 86400000);
});
test('Apple sandbox transactions remain isolated from production', () => {
  const sandbox = {...valid(), environment: 'Sandbox'};
  assert.equal(validateApplePurchase(sandbox, 'premium_monthly', 'customer-1', now), now + 86400000);
  assert.notEqual(appleSubscriptionKey(valid()), appleSubscriptionKey(sandbox));
});
for (const [label, patch] of [
  ['another app', {bundleId: 'com.other.app'}],
  ['another product', {productId: 'premium_yearly'}],
  ['another owner', {appAccountToken: appleAccountToken('customer-2')}],
  ['missing account binding', {appAccountToken: undefined}],
  ['expired subscription', {expiresDate: now}],
  ['refunded subscription', {revocationDate: now - 1}],
  ['future purchase', {purchaseDate: now + 3600000}],
  ['non-subscription purchase', {type: 'Consumable'}],
  ['family shared purchase', {inAppOwnershipType: 'FAMILY_SHARED'}],
  ['local unsigned StoreKit transaction', {environment: 'Xcode'}],
  ['unsafe original transaction id', {originalTransactionId: '../../users'}],
]) test(`reject ${label}`, () => assert.throws(() => validateApplePurchase({...valid(), ...patch}, 'premium_monthly', 'customer-1', now)));
test('unknown product cannot grant premium', () => {
  assert.equal(appleProducts.has('unknown'), false);
  assert.throws(() => validateApplePurchase({...valid(), productId: 'unknown'}, 'unknown', 'customer-1', now));
});
test('real Apple verifier rejects unsigned client payloads', async () => {
  const root = fs.readFileSync(path.join(__dirname, '../certificates/AppleRootCA-G3.pem'));
  const verifier = new SignedDataVerifier([root], true, Environment.PRODUCTION, appleBundleId, 6747984215);
  const header = Buffer.from(JSON.stringify({alg: 'none'})).toString('base64url');
  const payload = Buffer.from(JSON.stringify(valid())).toString('base64url');
  await assert.rejects(() => verifier.verifyAndDecodeTransaction(`${header}.${payload}.fake`));
});
