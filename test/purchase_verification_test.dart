import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ai_prospect_gps/services/purchase_verification.dart';

PurchaseDetails purchase(String data, {bool restored = false}) =>
    PurchaseDetails(
      productID: 'premium_monthly',
      purchaseID: '200000000000001',
      transactionDate: '123',
      status: restored ? PurchaseStatus.restored : PurchaseStatus.purchased,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: data,
        source: 'app_store',
      ),
    );

void main() {
  test('iOS sends its signed transaction to Apple validation only', () {
    final value = PurchaseVerification.forPurchase(
      purchase('header.payload.signature'),
      platform: TargetPlatform.iOS,
    );
    expect(value.functionName, 'verifyApplePurchase');
    expect(value.payload['signedTransaction'], 'header.payload.signature');
    expect(value.payload.containsKey('purchaseToken'), false);
  });
  test('Android still sends its purchase token to Google Play validation', () {
    final value = PurchaseVerification.forPurchase(
      purchase('google-token'),
      platform: TargetPlatform.android,
    );
    expect(value.functionName, 'verifyGooglePlayPurchase');
    expect(value.payload['purchaseToken'], 'google-token');
    expect(value.payload.containsKey('signedTransaction'), false);
  });
  test('restoration uses the same secure Apple validation', () {
    final value = PurchaseVerification.forPurchase(
      purchase('h.p.s', restored: true),
      platform: TargetPlatform.iOS,
    );
    expect(value.payload['isRestore'], true);
  });
  test(
    'missing proof and legacy receipts cannot be sent to the wrong store',
    () {
      expect(
        () => PurchaseVerification.forPurchase(
          purchase(''),
          platform: TargetPlatform.android,
        ),
        throwsFormatException,
      );
      expect(
        () => PurchaseVerification.forPurchase(
          purchase('base64-old-receipt'),
          platform: TargetPlatform.iOS,
        ),
        throwsFormatException,
      );
    },
  );
}
