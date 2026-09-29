import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const bool productionEnabled = bool.fromEnvironment(
    'ADMOB_PRODUCTION_ENABLED',
    defaultValue: false,
  );

  // Blocs AdMob de production Prospecto.
  static const String appOpenProduction =
      'ca-app-pub-1360261396564293/5583440067';
  static const String bannerHomeProduction =
      'ca-app-pub-1360261396564293/1162631714';
  static const String interstitialProduction =
      'ca-app-pub-1360261396564293/5482834887';

  // Identifiants de test officiels Google pour Android.
  // google_mobile_ads 2.0+ ne fournit plus les propriétés testAdUnitId.
  static const String _appOpenTest =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _bannerTest =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest =
      'ca-app-pub-3940256099942544/1033173712';

  static String get appOpen =>
      _useProduction ? appOpenProduction : _appOpenTest;

  static String get bannerHome =>
      _useProduction ? bannerHomeProduction : _bannerTest;

  static String get interstitial =>
      _useProduction ? interstitialProduction : _interstitialTest;

  static bool get _useProduction => kReleaseMode && productionEnabled;
}
