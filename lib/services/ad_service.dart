import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ad_config.dart';
import 'usage_meter.dart';

/// Centralise le consentement UMP et la publicité Prospecto.
///
/// Stratégie 1.3.8 :
/// - aucune publicité plein écran au lancement / retour depuis Maps ;
/// - bannière discrète gérée par les écrans FREE ;
/// - interstitiel uniquement lors d'une vraie pause dans le parcours ;
/// - jamais de publicité pour un utilisateur Premium ;
/// - cooldown persistant pour éviter l'effet « pop-up insupportable ».
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const Duration _premiumCacheTtl = Duration(minutes: 5);
  static const Duration _interstitialCooldown = Duration(minutes: 30);
  static const String _lastInterstitialKey = 'ads.last_interstitial_ms';

  InterstitialAd? _interstitial;
  DateTime? _lastInterstitialAt;
  DateTime? _premiumCheckedAt;
  bool? _cachedPremium;
  String? _cachedPremiumUid;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _showingFullScreen = false;
  bool _trackingResolved = false;
  bool _trackingAuthorized = false;
  static const _privacy = MethodChannel('prospecto/privacy');
  AdRequest get adRequest => AdRequest(
    nonPersonalizedAds:
        defaultTargetPlatform == TargetPlatform.iOS && !_trackingAuthorized
        ? true
        : null,
  );

  bool get canRequestAds => _canRequestAds;

  Future<void> initialize() async {
    if (!AdConfig.canUseAds) return;
    if (_initialized) return;
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await _privacy.invokeMethod<String>('requestTracking');
        _trackingAuthorized = status == 'authorized';
        _trackingResolved =
            status == 'authorized' ||
            status == 'denied' ||
            status == 'restricted';
      } catch (_) {
        _initialized = false;
        return;
      }
      if (!_trackingResolved) {
        _initialized = false;
        return;
      }
    }

    final completer = Completer<void>();
    final parameters = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      parameters,
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        await _finishInitialization();
        if (!completer.isCompleted) completer.complete();
      },
      (_) async {
        // Ne force jamais la publicité quand le consentement ne le permet pas.
        await _finishInitialization();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
  }

  Future<void> _finishInitialization() async {
    if (defaultTargetPlatform == TargetPlatform.iOS && !_trackingResolved)
      return;
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (!_canRequestAds) return;
    await MobileAds.instance.initialize();
    await _restoreInterstitialCooldown();
    _loadInterstitial();
  }

  Future<void> showPrivacyOptions() async {
    if (!AdConfig.canUseAds) return;
    if (defaultTargetPlatform == TargetPlatform.iOS && !_trackingResolved) {
      await initialize();
      if (!_trackingResolved) return;
    }
    await ConsentForm.showPrivacyOptionsForm((_) {});
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (_canRequestAds) {
      await MobileAds.instance.initialize();
      await _restoreInterstitialCooldown();
      _loadInterstitial();
    }
  }

  /// Permet aux écrans d'abonnement de mettre immédiatement à jour le statut
  /// sans refaire une lecture Firestore au prochain affichage publicitaire.
  void setPremiumStatus(bool premium) {
    _cachedPremiumUid = FirebaseAuth.instance.currentUser?.uid;
    _cachedPremium = premium;
    _premiumCheckedAt = DateTime.now();
    if (premium) {
      _interstitial?.dispose();
      _interstitial = null;
    } else if (_canRequestAds) {
      _loadInterstitial();
    }
  }

  Future<bool> _isPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_cachedPremiumUid != uid) {
      _cachedPremiumUid = uid;
      _cachedPremium = null;
      _premiumCheckedAt = null;
      _interstitial?.dispose();
      _interstitial = null;
    }

    final checkedAt = _premiumCheckedAt;
    if (_cachedPremium != null &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _premiumCacheTtl) {
      return _cachedPremium!;
    }

    try {
      final meter = UsageMeter();
      await meter.initIfNeeded();
      await meter.syncFromCloud();
      final premium = await meter.isPremium();
      _cachedPremiumUid = uid;
      _cachedPremium = premium;
      _premiumCheckedAt = DateTime.now();
      return premium;
    } catch (_) {
      // En cas d'erreur réseau, conserve un éventuel statut Premium connu.
      // Sinon on reste FREE sans bloquer l'application.
      return _cachedPremium ?? false;
    }
  }

  Future<void> _restoreInterstitialCooldown() async {
    if (_lastInterstitialAt != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_lastInterstitialKey);
      if (ms != null) {
        _lastInterstitialAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {
      // Le cooldown mémoire reste suffisant si le stockage local échoue.
    }
  }

  Future<void> _persistInterstitialShown(DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastInterstitialKey, when.millisecondsSinceEpoch);
    } catch (_) {}
  }

  void _loadInterstitial() {
    if (!_canRequestAds || _interstitial != null || _cachedPremium == true) {
      return;
    }
    InterstitialAd.load(
      adUnitId: AdConfig.interstitial,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Affiche un interstitiel uniquement à une pause naturelle du parcours
  /// (par ex. retour à l'accueil après avoir sauvegardé une tournée gratuite).
  /// Jamais au lancement, jamais lors d'un simple retour depuis Maps.
  Future<void> showInterstitialAtNaturalBreak() async {
    if (_showingFullScreen || !_canRequestAds || await _isPremium()) return;

    await _restoreInterstitialCooldown();
    final last = _lastInterstitialAt;
    if (last != null &&
        DateTime.now().difference(last) < _interstitialCooldown) {
      return;
    }

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    _interstitial = null;
    _showingFullScreen = true;
    final shownAt = DateTime.now();
    _lastInterstitialAt = shownAt;
    unawaited(_persistInterstitialShown(shownAt));

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// Vide tout état publicitaire lié au compte lors d'une déconnexion.
  /// Le cooldown reste volontairement commun à l'appareil : changer de compte
  /// ne permet pas de contourner la fréquence maximale des interstitiels.
  void resetAccountCache() {
    _cachedPremiumUid = null;
    _cachedPremium = null;
    _premiumCheckedAt = null;
    _showingFullScreen = false;
    _interstitial?.dispose();
    _interstitial = null;
    if (_canRequestAds) _loadInterstitial();
  }

  void dispose() {
    _interstitial?.dispose();
  }
}
