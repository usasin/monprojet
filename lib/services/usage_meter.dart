import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_test_mode.dart';
import 'workspace_scope.dart';

/// Compteur d'usage et cache léger des droits Prospecto.
///
/// Important : cette classe reste la source CLIENTE d'affichage/UX uniquement.
/// Les droits Premium réels continuent d'être écrits et vérifiés côté serveur.
/// Le singleton évite de relire Firestore plusieurs fois quand plusieurs écrans
/// vérifient les mêmes droits à quelques secondes d'intervalle.
class UsageMeter {
  UsageMeter._internal();

  static final UsageMeter _instance = UsageMeter._internal();
  factory UsageMeter() => _instance;

  static const int defaultFreeMaxProspectsPerTour = 3;
  static const int defaultFreeMaxTours = 1;

  /// Evite les rafales de lectures Firestore entre deux écrans successifs.
  /// Une action sensible (achat/restauration) peut utiliser forceRefresh: true.
  static const Duration _cloudSyncMinInterval = Duration(seconds: 45);

  bool _inited = false;
  String? _boundUid;
  bool _isPremium = false;
  int _freeToursUsed = 0;
  String _activePlan = 'FREE';
  bool _weekPlannerTrialUsed = false;
  DateTime? _premiumUntil;
  DateTime? _lastCloudSyncAt;
  Future<void>? _syncInFlight;

  DocumentReference<Map<String, dynamic>>? _userRef;

  int get maxFreeProspectsPerTour => defaultFreeMaxProspectsPerTour;
  String get activePlan => _activePlan;
  DateTime? get premiumUntil => _premiumUntil;

  void _applyAdminTestOverride() {
    if (!AdminTestMode.enabled) return;
    _isPremium = true;
    _activePlan = 'ADMIN_TEST';
    _premiumUntil = null;
  }

  Future<void> initIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    // Le singleton peut survivre à une déconnexion/reconnexion : dans ce cas
    // on invalide proprement tout l'état local avant de se rattacher au compte.
    if (_inited && _boundUid == uid) return;

    _inited = true;
    _boundUid = uid;
    _userRef = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid);
    _isPremium = false;
    _freeToursUsed = 0;
    _activePlan = 'FREE';
    _weekPlannerTrialUsed = false;
    _premiumUntil = null;
    _lastCloudSyncAt = null;
    _syncInFlight = null;
    _applyAdminTestOverride();
  }

  /// Synchronise les droits/compteurs depuis Firestore.
  ///
  /// Par défaut, une valeur récupérée il y a moins de 45 secondes est réutilisée
  /// afin d'éviter plusieurs lectures identiques pendant une même navigation.
  /// Après un achat/restauration, passer [forceRefresh] à true.
  Future<void> syncFromCloud({bool forceRefresh = false}) async {
    await initIfNeeded();
    if (AdminTestMode.enabled) {
      _applyAdminTestOverride();
      return;
    }
    final ref = _userRef;
    if (ref == null) return;

    final now = DateTime.now();
    final last = _lastCloudSyncAt;
    if (!forceRefresh &&
        last != null &&
        now.difference(last) < _cloudSyncMinInterval) {
      return;
    }

    final current = _syncInFlight;
    if (current != null) {
      await current;
      return;
    }

    final future = _performCloudSync(ref, forceRefresh: forceRefresh);
    _syncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _performCloudSync(
    DocumentReference<Map<String, dynamic>> ref, {
    required bool forceRefresh,
  }) async {
    final data = (await ref.get()).data();
    if (data == null) {
      _lastCloudSyncAt = DateTime.now();
      return;
    }

    // Les droits Premium sont exclusivement écrits par Cloud Functions.
    final entitlements =
        (data['entitlements'] as Map?)?.cast<String, dynamic>() ?? const {};
    final usage = (data['usage'] as Map?)?.cast<String, dynamic>() ?? const {};

    _premiumUntil = _date(entitlements['premiumUntil']);
    final serverPremium = entitlements['isPremium'] == true;
    _isPremium = serverPremium &&
        (_premiumUntil == null || _premiumUntil!.isAfter(DateTime.now()));
    _activePlan = (entitlements['activePlan'] as String?) ??
        (_isPremium ? 'PREMIUM' : 'FREE');

    // Le compte développeur est autorisé par une custom claim Firebase,
    // jamais par une valeur modifiable dans Firestore depuis le téléphone.
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
      if (token?.claims?['prospectoDeveloper'] == true) {
        _isPremium = true;
        _activePlan = 'DEVELOPER';
        _premiumUntil = null;
      }
    } catch (_) {
      // Le contrôle normal des droits reste disponible hors connexion.
    }

    // Un abonnement entreprise actif donne les droits Premium à tous les
    // membres de l'organisation. On réutilise le cache WorkspaceScope pendant
    // les navigations normales ; un refresh forcé reste disponible après une
    // opération qui change réellement les droits.
    try {
      final scope = await WorkspaceScope.resolve(forceRefresh: forceRefresh);
      if (scope.isTeam) {
        final org = await scope.orgRef.get();
        final orgData = org.data() ?? const <String, dynamic>{};
        final status = (orgData['status'] ?? 'active').toString().toLowerCase();
        final plan = (orgData['plan'] ?? 'STANDARD').toString().toUpperCase();
        final enterpriseActive = status == 'active' &&
            !const {'FREE', 'INACTIVE', 'EXPIRED', 'CANCELLED'}.contains(plan);
        if (enterpriseActive) {
          _isPremium = true;
          _activePlan = 'ENTREPRISE_$plan';
          final enterpriseUntil = _date(orgData['subscriptionUntil']);
          _premiumUntil = enterpriseUntil;
          if (enterpriseUntil != null &&
              !enterpriseUntil.isAfter(DateTime.now())) {
            _isPremium = false;
            _activePlan = 'FREE';
          }
        }
      }
    } catch (_) {
      // Le droit personnel reste la source de repli en cas d'indisponibilité.
    }

    // Migration transparente des anciens compteurs stockés dans entitlements.
    _freeToursUsed = ((usage['freeToursUsed'] ??
                entitlements['freeToursUsed'] ??
                0) as num)
            .toInt();
    _weekPlannerTrialUsed =
        (usage['weekPlannerTrialUsed'] ??
                entitlements['weekPlannerTrialUsed']) ==
            true;

    _lastCloudSyncAt = DateTime.now();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Le client peut uniquement modifier ses compteurs d'usage. Les droits
  /// Premium et le plan actif ne sont jamais envoyés depuis le téléphone.
  Future<void> pushToCloud() async {
    await initIfNeeded();
    final ref = _userRef;
    if (ref == null) return;
    await ref.set({
      'usage': {
        'freeToursUsed': _freeToursUsed,
        'weekPlannerTrialUsed': _weekPlannerTrialUsed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<bool> isPremium() async {
    await initIfNeeded();
    if (AdminTestMode.enabled) return true;
    return _isPremium;
  }

  Future<int> getFreeToursUsed() async {
    await initIfNeeded();
    return _freeToursUsed;
  }

  Future<bool> getWeekPlannerTrialUsed() async {
    await initIfNeeded();
    return _weekPlannerTrialUsed;
  }

  Future<bool> canUseWeekPlannerTrial({
    required int totalProspects,
    int maxTrialProspects = 50,
  }) async {
    await initIfNeeded();
    if (_isPremium) return true;
    if (_weekPlannerTrialUsed) return false;
    return totalProspects <= maxTrialProspects;
  }

  Future<void> markWeekPlannerTrialUsed() async {
    await initIfNeeded();
    if (_isPremium) return;
    _weekPlannerTrialUsed = true;
  }

  Future<void> markFreeTourUsed() async {
    await initIfNeeded();
    if (_isPremium) return;
    _freeToursUsed = defaultFreeMaxTours;
  }

  Future<void> incrementFreeToursUsed() async {
    await initIfNeeded();
    if (_isPremium) return;
    _freeToursUsed += 1;
  }

  Future<bool> canCreateNewTour(int prospectCount) async {
    await initIfNeeded();
    if (_isPremium) return true;
    if (prospectCount > defaultFreeMaxProspectsPerTour) return false;
    return _freeToursUsed < defaultFreeMaxTours;
  }

  Future<bool> canUseText(int tokens) async => true;
  Future<bool> canUseAudio(int seconds) async => true;
}
