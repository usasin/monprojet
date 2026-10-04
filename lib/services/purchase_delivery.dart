import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'in_app_purchase_service.dart';
import 'usage_meter.dart';
import 'purchase_verification.dart';

class DeliveryResult {
  final bool delivered;
  final bool ignored;
  final bool isRestore;
  final String? message;

  const DeliveryResult({
    required this.delivered,
    required this.ignored,
    required this.isRestore,
    this.message,
  });
}

class PurchaseDelivery {
  static bool _isPremium(String id) =>
      id == InAppPurchaseService.premiumMonthly ||
      id == InAppPurchaseService.premiumYearly;

  /// Vérifie la transaction auprès de sa boutique via Cloud Functions avant
  /// d'accorder un droit. Aucun abonnement n'est activé par le téléphone.
  static Future<DeliveryResult> deliver(
    PurchaseDetails purchase, {
    required UsageMeter meter,
  }) async {
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return const DeliveryResult(
        delivered: false,
        ignored: true,
        isRestore: false,
      );
    }
    if (!_isPremium(purchase.productID)) {
      return DeliveryResult(
        delivered: false,
        ignored: true,
        isRestore: purchase.status == PurchaseStatus.restored,
        message: 'Produit non reconnu.',
      );
    }

    try {
      final verification = PurchaseVerification.forPurchase(
        purchase,
        platform: defaultTargetPlatform,
      );
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable(verification.functionName);
      final response = await callable.call(verification.payload);
      final data = Map<String, dynamic>.from(response.data as Map);
      final verified = data['delivered'] == true || data['verified'] == true;
      await meter.syncFromCloud(forceRefresh: true);
      return DeliveryResult(
        delivered: verified,
        ignored: false,
        isRestore: purchase.status == PurchaseStatus.restored,
        message: verified
            ? (purchase.status == PurchaseStatus.restored
                  ? 'Abonnement restauré et vérifié.'
                  : 'Abonnement activé et vérifié !')
            : (data['message']?.toString() ??
                  'L’achat n’a pas pu être vérifié par la boutique.'),
      );
    } on FormatException catch (e) {
      return DeliveryResult(
        delivered: false,
        ignored: false,
        isRestore: purchase.status == PurchaseStatus.restored,
        message: e.message,
      );
    } on FirebaseFunctionsException catch (e) {
      return DeliveryResult(
        delivered: false,
        ignored: false,
        isRestore: purchase.status == PurchaseStatus.restored,
        message:
            e.message ??
            'Vérification serveur indisponible. L’achat sera retenté automatiquement.',
      );
    } catch (_) {
      return DeliveryResult(
        delivered: false,
        ignored: false,
        isRestore: purchase.status == PurchaseStatus.restored,
        message:
            'Vérification serveur indisponible. L’achat sera retenté automatiquement.',
      );
    }
  }
}
