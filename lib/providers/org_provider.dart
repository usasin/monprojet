import 'dart:async';
import '../sales/enterprise_display.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../services/workspace_preferences.dart';
import '../services/workspace_scope.dart';

class OrgProvider with ChangeNotifier {
  String? _orgId;
  String? _orgName;
  String? _role;
  String? _logoUrl;
  String? _slogan;
  String? _companyEmail;
  String? _companyPhone;
  String? _website;
  bool _busy = false;
  int _accessRevocation = 0;
  int get accessRevocation => _accessRevocation;
  EnterpriseDisplaySettings _displaySettings =
      const EnterpriseDisplaySettings();
  EnterpriseDisplaySettings get displaySettings => _displaySettings;
  bool _isTeam = false;
  bool _teamAvailable = false;
  String? _teamOrgId;
  String? _teamOrgName;
  String? _teamRole;
  String? _accessMessage;
  String? _plan;
  int? _maxSeats;
  DateTime? _subscriptionUntil;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberWatch;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orgWatch;
  bool _handlingAccessLoss = false;
  bool _developerTest = false;
  bool _routeAutonomy = true;
  DateTime? _lastActivityAt;

  String? get orgId => _orgId;
  String? get orgName => _orgName;
  String? get role => _role;
  String? get logoUrl => _logoUrl;
  String? get slogan => _slogan;
  String? get companyEmail => _companyEmail;
  String? get companyPhone => _companyPhone;
  String? get website => _website;
  bool get busy => _busy;
  bool get isTeam => _isTeam;
  bool get isPersonal => !_isTeam;
  bool get teamAvailable => _teamAvailable;
  String? get teamOrgId => _teamOrgId;
  String? get teamOrgName => _teamOrgName;
  String? get teamRole => _teamRole;
  String? get accessMessage => _accessMessage;
  String? get plan => _plan;
  int? get maxSeats => _maxSeats;
  DateTime? get subscriptionUntil => _subscriptionUntil;
  bool get developerTest => _developerTest;
  bool get routeAutonomy => _routeAutonomy;
  DateTime? get lastActivityAt => _lastActivityAt;
  bool get canPlanAutonomously => true;

  bool get canManageTeam =>
      _isTeam &&
      (_role?.toUpperCase() == 'OWNER' || _role?.toUpperCase() == 'MANAGER');
  bool get isOwner => _isTeam && _role?.toUpperCase() == 'OWNER';

  String get roleLabel {
    switch (_role?.toUpperCase()) {
      case 'OWNER':
        return 'Administrateur principal';
      case 'MANAGER':
        return 'Responsable commercial';
      case 'REP':
        return 'Commercial';
      default:
        return _isTeam ? 'Membre' : 'Personnel';
    }
  }

  String get workspaceLabel => _isTeam ? 'Entreprise' : 'Personnel';

  String get roleHomeTitle {
    switch (_role?.toUpperCase()) {
      case 'OWNER':
        return 'Pilotez votre entreprise';
      case 'MANAGER':
        return 'Pilotez votre équipe commerciale';
      case 'REP':
        return _routeAutonomy
            ? 'Organisez et réalisez vos tournées'
            : 'Réalisez les tournées attribuées';
      default:
        return 'Votre outil terrain 🚀';
    }
  }

  String get roleHomeSubtitle {
    switch (_role?.toUpperCase()) {
      case 'OWNER':
        return 'Gérez les responsables, les commerciaux, les calendriers et les résultats.';
      case 'MANAGER':
        return 'Attribuez les tournées, complétez les calendriers et suivez les reportings.';
      case 'REP':
        return _routeAutonomy
            ? 'Créez vos tournées et exécutez aussi celles attribuées par votre responsable.'
            : 'Consultez votre planning, réalisez les visites et complétez vos reportings.';
      default:
        return 'Planifiez, prospectez et analysez vos tournées commerciales en quelques secondes.';
    }
  }

  String get initials {
    final source = (_orgName ?? 'Entreprise').trim();
    if (source.isEmpty) return 'EN';
    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    return words.map((word) => word[0].toUpperCase()).join();
  }

  void setAccessMessage(String message) {
    _accessMessage = message;
  }

  void consumeAccessMessage() {
    if (_accessMessage == null) return;
    _accessMessage = null;
    notifyListeners();
  }

  void clear() {
    _stopTeamWatch();
    _displaySettings = const EnterpriseDisplaySettings();
    _orgId = null;
    _orgName = null;
    _role = null;
    _logoUrl = null;
    _slogan = null;
    _companyEmail = null;
    _companyPhone = null;
    _website = null;
    _isTeam = false;
    _teamAvailable = false;
    _teamOrgId = null;
    _teamOrgName = null;
    _teamRole = null;
    _accessMessage = null;
    _plan = null;
    _maxSeats = null;
    _subscriptionUntil = null;
    _developerTest = false;
    _routeAutonomy = true;
    _lastActivityAt = null;
    WorkspaceScope.invalidate();
    notifyListeners();
  }

  Future<void> loadFromUser(
    String uid, {
    bool preferSavedWorkspace = true,
    bool preferTeam = false,
  }) async {
    _setBusy(true);
    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(uid);
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final declaredType = data['currentOrgType']?.toString().toLowerCase();
      final oldCurrentId = (data['currentOrgId'] ?? data['orgId'])?.toString();
      _teamOrgId = (data['teamOrgId'] ?? oldCurrentId)?.toString();
      _teamOrgName =
          (data['teamOrgName'] ?? data['currentOrgName'] ?? data['orgName'])
              ?.toString();
      _teamRole = (data['teamRole'] ?? data['currentRole'] ?? data['role'])
          ?.toString();

      Map<String, dynamic>? teamData;
      Map<String, dynamic>? memberData;
      if (_teamOrgId != null && _teamOrgId!.trim().isNotEmpty) {
        try {
          final id = _teamOrgId!.trim();
          final memberRef = db
              .collection('apps')
              .doc(kAppId)
              .collection('orgs')
              .doc(id)
              .collection('members')
              .doc(uid);
          final orgRef = db
              .collection('apps')
              .doc(kAppId)
              .collection('orgs')
              .doc(id);
          final member = await memberRef.get();
          final org = await orgRef.get();
          memberData = member.data();
          teamData = org.data();
          _teamAvailable =
              member.exists &&
              memberData?['status']?.toString().toLowerCase() == 'active' &&
              org.exists &&
              _organizationIsAccessible(teamData ?? const {});
          if (_teamAvailable) {
            _teamOrgName = (teamData?['name'] ?? _teamOrgName)?.toString();
            _teamRole = (memberData?['role'] ?? _teamRole)?.toString();
          }
        } on FirebaseException {
          _teamAvailable = false;
        }
      } else {
        _teamAvailable = false;
      }

      var desiredType = declaredType;
      if (preferSavedWorkspace) {
        desiredType = await WorkspacePreferences.lastWorkspace() ?? desiredType;
      }

      if (preferTeam && _teamAvailable) desiredType = 'team';
      if (desiredType == 'team' && _teamAvailable) {
        _applyTeam(teamData ?? const {}, memberData ?? const {});
        await _persistTeamWorkspace(
          userRef,
          orgId: _teamOrgId!,
          orgName: _orgName ?? _teamOrgName ?? 'Entreprise',
          role: _role ?? _teamRole ?? 'REP',
        );
        _startTeamWatch(uid);
      } else {
        if (desiredType == 'team' && !_teamAvailable) {
          _accessMessage =
              'Votre espace entreprise n’est plus accessible. Vous êtes revenu dans votre espace personnel.';
        }
        await _persistPersonalWorkspace(userRef);
        _stopTeamWatch();
        _applyPersonal();
      }
      WorkspaceScope.invalidate();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> switchToPersonal(String uid) async {
    _setBusy(true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      await _persistPersonalWorkspace(ref);
      _stopTeamWatch();
      _applyPersonal();
      WorkspaceScope.invalidate();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> switchToTeam(String uid) async {
    final id = _teamOrgId;
    if (id == null || id.isEmpty) {
      throw StateError('Aucun espace entreprise associé à ce compte.');
    }
    _setBusy(true);
    try {
      final db = FirebaseFirestore.instance;
      final orgRef = db
          .collection('apps')
          .doc(kAppId)
          .collection('orgs')
          .doc(id);
      final memberRef = orgRef.collection('members').doc(uid);
      final org = await orgRef.get();
      final member = await memberRef.get();
      final orgData = org.data() ?? const <String, dynamic>{};
      final memberData = member.data() ?? const <String, dynamic>{};

      if (!org.exists ||
          !member.exists ||
          memberData['status']?.toString().toLowerCase() != 'active' ||
          !_organizationIsAccessible(orgData)) {
        _teamAvailable = false;
        _applyPersonal();
        await _persistPersonalWorkspace(db.collection('users').doc(uid));
        throw StateError(
          'Votre accès à cet espace entreprise n’est plus actif.',
        );
      }

      final name = (orgData['name'] ?? 'Entreprise').toString();
      final role = (memberData['role'] ?? 'REP').toString().toUpperCase();
      await _persistTeamWorkspace(
        db.collection('users').doc(uid),
        orgId: id,
        orgName: name,
        role: role,
      );
      _teamAvailable = true;
      _teamOrgName = name;
      _teamRole = role;
      _applyTeam(orgData, memberData);
      _startTeamWatch(uid);
      WorkspaceScope.invalidate();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'not-found' ||
          error.code == 'failed-precondition') {
        _teamAvailable = false;
        _applyPersonal();
        await _persistPersonalWorkspace(
          FirebaseFirestore.instance.collection('users').doc(uid),
        );
        WorkspaceScope.invalidate();
        throw StateError(
          'Votre accès à cet espace entreprise n’est plus actif.',
        );
      }
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> refresh(String uid) =>
      loadFromUser(uid, preferSavedWorkspace: false);

  bool _organizationIsAccessible(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'active').toString().toLowerCase();
    if (status != 'active') return false;
    final rawUntil = data['subscriptionUntil'];
    DateTime? until;
    if (rawUntil is Timestamp) until = rawUntil.toDate();
    if (rawUntil is DateTime) until = rawUntil;
    if (rawUntil is String) until = DateTime.tryParse(rawUntil);
    return until == null || until.isAfter(DateTime.now());
  }

  void _applyTeam(
    Map<String, dynamic> orgData,
    Map<String, dynamic> memberData,
  ) {
    _displaySettings = EnterpriseDisplaySettings.fromMap(
      orgData['displaySettings'],
    );
    _isTeam = true;
    _orgId = _teamOrgId;
    _orgName = (orgData['name'] ?? _teamOrgName ?? 'Entreprise').toString();
    _role = (memberData['role'] ?? _teamRole ?? 'REP').toString().toUpperCase();
    _logoUrl = orgData['logoUrl']?.toString();
    _slogan = orgData['slogan']?.toString();
    _companyEmail = orgData['companyEmail']?.toString();
    _companyPhone = orgData['companyPhone']?.toString();
    _website = orgData['website']?.toString();
    _plan = orgData['plan']?.toString();
    _maxSeats = (orgData['maxSeats'] as num?)?.toInt();
    _subscriptionUntil = _toDate(orgData['subscriptionUntil']);
    _developerTest = orgData['developerTest'] == true;
    _routeAutonomy = true;
    _lastActivityAt = _toDate(
      memberData['lastActivityAt'] ?? memberData['joinedAt'],
    );
    _teamOrgName = _orgName;
    _teamRole = _role;
  }

  void _applyPersonal() {
    _isTeam = false;
    _displaySettings = const EnterpriseDisplaySettings();
    _orgId = null;
    _orgName = 'Mon espace personnel';
    _role = 'PERSONAL';
    _logoUrl = null;
    _slogan = null;
    _companyEmail = null;
    _companyPhone = null;
    _website = null;
    _plan = null;
    _maxSeats = null;
    _subscriptionUntil = null;
    _developerTest = false;
    _routeAutonomy = true;
    _lastActivityAt = null;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _startTeamWatch(String uid) {
    final id = _teamOrgId;
    if (id == null || id.isEmpty) return;
    _stopTeamWatch();
    final orgRef = FirebaseFirestore.instance
        .collection('apps')
        .doc(kAppId)
        .collection('orgs')
        .doc(id);
    _memberWatch = orgRef.collection('members').doc(uid).snapshots().listen((
      snapshot,
    ) {
      if (!_isTeam || _teamOrgId != id) return;
      final data = snapshot.data();
      if (!snapshot.exists ||
          data?['status']?.toString().toLowerCase() != 'active') {
        _handleAccessLost(uid);
        return;
      }
      final role = (data?['role'] ?? _role ?? 'REP').toString().toUpperCase();
      _role = role;
      _teamRole = role;
      _routeAutonomy = true;
      _lastActivityAt = _toDate(data?['lastActivityAt'] ?? data?['joinedAt']);
      WorkspaceScope.invalidate();
      notifyListeners();
    }, onError: (Object error) => _handleWatchError(uid, error));
    _orgWatch = orgRef.snapshots().listen((snapshot) {
      if (!_isTeam || _teamOrgId != id) return;
      final data = snapshot.data();
      if (!snapshot.exists || !_organizationIsAccessible(data ?? const {})) {
        _handleAccessLost(uid);
        return;
      }
      if (_isTeam) {
        _applyTeam(data ?? const {}, {
          'role': _role,
          'routeAutonomy': _routeAutonomy,
          'lastActivityAt': _lastActivityAt,
        });
        notifyListeners();
      }
    }, onError: (Object error) => _handleWatchError(uid, error));
  }

  void _handleWatchError(String uid, Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      _handleAccessLost(uid);
    }
  }

  Future<void> _handleAccessLost(String uid) async {
    if (_handlingAccessLoss || !_isTeam) return;
    _handlingAccessLoss = true;
    try {
      _stopTeamWatch();
      _accessRevocation++;
      _teamAvailable = false;
      _teamOrgId = null;
      _teamOrgName = null;
      _teamRole = null;
      _applyPersonal();
      _accessMessage =
          'Vous n’avez plus accès à cet espace entreprise. Votre espace personnel a été ouvert.';
      WorkspaceScope.invalidate();
      notifyListeners();
      await _persistPersonalWorkspace(
        FirebaseFirestore.instance.collection('users').doc(uid),
      );
    } catch (_) {
      // La vérification sera reprise au prochain lancement ou changement d’espace.
    } finally {
      _handlingAccessLoss = false;
    }
  }

  void _stopTeamWatch() {
    _memberWatch?.cancel();
    _orgWatch?.cancel();
    _memberWatch = null;
    _orgWatch = null;
  }

  @override
  void dispose() {
    _stopTeamWatch();
    super.dispose();
  }

  Future<void> _persistTeamWorkspace(
    DocumentReference<Map<String, dynamic>> userRef, {
    required String orgId,
    required String orgName,
    required String role,
  }) async {
    final normalizedRole = role.toUpperCase();
    await userRef.set({
      'currentOrgId': orgId,
      'currentOrgName': orgName,
      'currentRole': normalizedRole,
      'currentOrgType': 'team',
      'teamOrgId': orgId,
      'teamOrgName': orgName,
      'teamRole': normalizedRole,
      'orgId': orgId,
      'orgName': orgName,
      'role': normalizedRole,
      'orgIds': FieldValue.arrayUnion([orgId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await WorkspacePreferences.setLastWorkspace('team');
  }

  Future<void> _persistPersonalWorkspace(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    await userRef.set({
      'currentOrgType': 'personal',
      'currentOrgId': FieldValue.delete(),
      'currentOrgName': FieldValue.delete(),
      'currentRole': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await WorkspacePreferences.setLastWorkspace('personal');
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
