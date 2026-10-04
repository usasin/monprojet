import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class InAppPurchaseService {
  // The same product identifiers are configured in Google Play and App Store Connect.
  static const String premiumMonthly = 'premium_monthly';
  static const String premiumYearly = 'premium_yearly';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};
  bool _available = false;

  bool get isAvailable => _available;

  ProductDetails? getProduct(String id) => _products[id];

  List<ProductDetails> get allProducts => _products.values.toList();

  // Purchase callback
  final Future<bool> Function(PurchaseDetails purchase) onDeliverPurchase;

  InAppPurchaseService({required this.onDeliverPurchase});

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub?.cancel();
    _sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        await _handlePurchase(p);
      }
    }, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<bool> loadProducts({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!_available) {
      _available = await _iap.isAvailable();
      if (!_available) return false;
    }

    final ids = <String>{premiumMonthly, premiumYearly};

    final resp = await _iap.queryProductDetails(ids).timeout(timeout);

    _products.clear();
    for (final p in resp.productDetails) {
      _products[p.id] = p;
    }

    return resp.notFoundIDs.isEmpty || _products.isNotEmpty;
  }

  Future<void> buy(ProductDetails product) async {
    String? accountToken;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final response = await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('getApplePurchaseAccount').call();
      accountToken = (response.data as Map)['appAccountToken'] as String;
    }
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: accountToken,
    );
    // Subscriptions are handled like non-consumables in in_app_purchase.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) return;

    if (purchase.status == PurchaseStatus.error) {
      // Complete the purchase to avoid it being stuck.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    // purchased or restored : ne finalise la transaction qu'après validation
    // serveur afin d'éviter d'accorder un abonnement non vérifié.
    final verified = await onDeliverPurchase(purchase);

    if (verified && purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}
