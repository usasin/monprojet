import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/services/ad_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS requests iOS test ads, never Android ads', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AdConfig.canUseAds, isTrue);
    expect(AdConfig.bannerHome, 'ca-app-pub-3940256099942544/2934735716');
    expect(AdConfig.interstitial, 'ca-app-pub-3940256099942544/4411468910');
    expect(AdConfig.appOpen, 'ca-app-pub-3940256099942544/5575463023');
  });

  test('Android retains Android test ads', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AdConfig.canUseAds, isTrue);
    expect(AdConfig.bannerHome, 'ca-app-pub-3940256099942544/6300978111');
    expect(AdConfig.interstitial, 'ca-app-pub-3940256099942544/1033173712');
  });

  test('desktop does not initialize the mobile ad SDK', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(AdConfig.canUseAds, isFalse);
  });
}
