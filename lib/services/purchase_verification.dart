import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseVerification {
  const PurchaseVerification(this.functionName, this.payload);
  final String functionName;
  final Map<String, dynamic> payload;

  factory PurchaseVerification.forPurchase(
    PurchaseDetails purchase, {
    required TargetPlatform platform,
  }) {
    final data = purchase.verificationData.serverVerificationData.trim();
    if (data.isEmpty) throw const FormatException('Preuve d’achat manquante.');
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (apple && data.split('.').length != 3) {
      throw const FormatException(
        'Transaction Apple indisponible. Réessayez la restauration depuis TestFlight ou l’App Store.',
      );
    }
    return PurchaseVerification(
      apple ? 'verifyApplePurchase' : 'verifyGooglePlayPurchase',
      <String, dynamic>{
        'productId': purchase.productID,
        apple ? 'signedTransaction' : 'purchaseToken': data,
        'isRestore': purchase.status == PurchaseStatus.restored,
      },
    );
  }
}
