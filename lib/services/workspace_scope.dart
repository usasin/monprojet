import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';

/// Résout l'emplacement Firestore actif de l'utilisateur.
///
/// - Personnel : /users/{uid}/...
/// - Entreprise :
///   - prospects partagés : /apps/{appId}/orgs/{orgId}/prospects
///   - données personnelles de tournée :
///     /apps/{appId}/orgs/{orgId}/memberData/{uid}/...
class WorkspaceScope {
  WorkspaceScope._({
    required this.uid,
    required this.isTeam,
    this.orgId,
    this.orgName,
    this.role,
    this.routeAutonomy = true,
  });

  final String uid;
  final bool isTeam;
  final String? orgId;
  final String? orgName;
  final String? role;
  final bool routeAutonomy;

  bool get canPlanAutonomously => !isTeam ||
      role?.toUpperCase() == 'OWNER' ||
      role?.toUpperCase() == 'MANAGER' ||
      routeAutonomy;

  static WorkspaceScope? _cached;
  static DateTime? _cachedAt;

  static void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  static Future<WorkspaceScope> resolve({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Vous devez être connecté.');

    final now = DateTime.now();
    final cached = _cached;
    if (!forceRefresh &&
        cached != null &&
        cached.uid == user.uid &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 2)) {
      return cached;
    }

    final db = FirebaseFirestore.instance;
    final userSnap = await db.collection('users').doc(user.uid).get();
    final data = userSnap.data() ?? const <String, dynamic>{};
    final declaredType = data['currentOrgType']?.toString().toLowerCase();
    final orgId = (data['currentOrgId'] ??
            (declaredType == 'team' ? data['teamOrgId'] : null) ??
            (declaredType == 'team' ? data['orgId'] : null))
        ?.toString()
        .trim();

    var isTeam = declaredType == 'team' && orgId != null && orgId.isNotEmpty;
    String? orgName = (data['currentOrgName'] ?? data['teamOrgName'])?.toString();
    String? role = (data['currentRole'] ?? data['teamRole'])?.toString();
    var routeAutonomy = true;

    if (isTeam) {
      final teamId = orgId;
      if (teamId == null || teamId.isEmpty) {
        throw StateError('Aucun espace entreprise actif.');
      }
      final orgRef = db
          .collection('apps')
          .doc(kAppId)
          .collection('orgs')
          .doc(teamId);
      final memberRef = orgRef.collection('members').doc(user.uid);
      final org = await orgRef.get();
      final member = await memberRef.get();
      final orgData = org.data() ?? const <String, dynamic>{};
      final memberData = member.data() ?? const <String, dynamic>{};
      final status = (orgData['status'] ?? 'active').toString().toLowerCase();
      final activeMember = member.exists &&
          memberData['status']?.toString().toLowerCase() == 'active';
      final activeSubscription = _activeSubscription(orgData['subscriptionUntil']);
      isTeam = org.exists && activeMember && status == 'active' && activeSubscription;
      if (!isTeam) {
        throw StateError('Votre accès à cet espace entreprise n’est plus actif.');
      }
      orgName = (orgData['name'] ?? orgName ?? 'Entreprise').toString();
      role = (memberData['role'] ?? role ?? 'REP').toString();
      final normalizedRole = role.toUpperCase();
      routeAutonomy = normalizedRole == 'OWNER' || normalizedRole == 'MANAGER'
          ? true
          : memberData['routeAutonomy'] == true;
    }

    final result = WorkspaceScope._(
      uid: user.uid,
      isTeam: isTeam,
      orgId: isTeam ? orgId : null,
      orgName: isTeam ? orgName : 'Mon espace personnel',
      role: isTeam ? role : 'PERSONAL',
      routeAutonomy: isTeam ? routeAutonomy : true,
    );
    _cached = result;
    _cachedAt = now;
    return result;
  }

  static bool _activeSubscription(dynamic rawUntil) {
    DateTime? until;
    if (rawUntil is Timestamp) until = rawUntil.toDate();
    if (rawUntil is DateTime) until = rawUntil;
    if (rawUntil is String) until = DateTime.tryParse(rawUntil);
    return until == null || until.isAfter(DateTime.now());
  }

  FirebaseFirestore get db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get userRef =>
      db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> get orgRef {
    final id = orgId;
    if (!isTeam || id == null || id.isEmpty) {
      throw StateError('Aucun espace entreprise actif.');
    }
    return db.collection('apps').doc(kAppId).collection('orgs').doc(id);
  }

  CollectionReference<Map<String, dynamic>> get prospects =>
      isTeam ? orgRef.collection('prospects') : userRef.collection('prospects');

  DocumentReference<Map<String, dynamic>> get memberDataRef =>
      isTeam ? orgRef.collection('memberData').doc(uid) : userRef;

  CollectionReference<Map<String, dynamic>> get plans =>
      memberDataRef.collection('plans');

  CollectionReference<Map<String, dynamic>> get reminders =>
      memberDataRef.collection('reminders');

  CollectionReference<Map<String, dynamic>> get activity {
    if (!isTeam) throw StateError('Aucun historique entreprise en mode personnel.');
    return orgRef.collection('activity');
  }
}
