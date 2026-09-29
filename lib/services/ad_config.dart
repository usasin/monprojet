import 'package:flutter/foundation.dart';

import 'admin_test_mode.dart';

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

  static const String iosBanner = String.fromEnvironment('ADMOB_IOS_BANNER_ID');
  static const String iosInterstitial =
      String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID');
  static const String iosAppOpen = String.fromEnvironment('ADMOB_IOS_APP_OPEN_ID');

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get canUseAds => !kIsWeb && !AdminTestMode.enabled &&
      (defaultTargetPlatform == TargetPlatform.android ||
       (_isIOS && (!_useProduction ||
         (iosBanner.isNotEmpty && iosInterstitial.isNotEmpty))));

  static String get appOpen => _isIOS
      ? (_useProduction ? iosAppOpen : 'ca-app-pub-3940256099942544/5575463023')
      : (_useProduction ? appOpenProduction : _appOpenTest);

  static String get bannerHome => _isIOS
      ? (_useProduction ? iosBanner : 'ca-app-pub-3940256099942544/2934735716')
      : (_useProduction ? bannerHomeProduction : _bannerTest);

  static String get interstitial => _isIOS
      ? (_useProduction ? iosInterstitial : 'ca-app-pub-3940256099942544/4411468910')
      : (_useProduction ? interstitialProduction : _interstitialTest);

  static bool get _useProduction => kReleaseMode && productionEnabled;
}
