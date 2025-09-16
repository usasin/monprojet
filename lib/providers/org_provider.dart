import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrgProvider with ChangeNotifier {
  String? _orgId;
  String? _orgName;
  bool _busy = false;

  String? get orgId => _orgId;
  String? get orgName => _orgName;
  bool get busy => _busy;

  set _setBusy(bool v) { _busy = v; notifyListeners(); }

  /// Charge l’org courante depuis users/{uid}
  Future<void> loadFromUser(String uid) async {
    _setBusy = true;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      _orgId = data['currentOrgId'] as String?;
      if (_orgId != null) {
        final o = await FirebaseFirestore.instance.collection('orgs').doc(_orgId).get();
        _orgName = (o.data() ?? {})['name'] as String?;
      }
    } finally {
      _setBusy = false;
    }
  }

  /// Crée une org privée “solo-{uid}” et l’assigne à l’utilisateur
  Future<void> createSoloOrgForUser(String uid, {String? displayName}) async {
    _setBusy = true;
    try {
      final db = FirebaseFirestore.instance;
      final orgRef = db.collection('orgs').doc(); // id auto
      final batch = db.batch();

      batch.set(orgRef, {
        'name'     : displayName == null || displayName.isEmpty
            ? 'Mon espace solo'
            : 'Espace de $displayName',
        'type'     : 'solo',
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'plan'     : 'free',
      });

      // Membre owner
      batch.set(orgRef.collection('members').doc(uid), {
        'role'    : 'owner',
        'status'  : 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Marque l’org sur le user
      final userRef = db.collection('users').doc(uid);
      batch.set(userRef, {
        'currentOrgId': orgRef.id,
        'orgIds'      : FieldValue.arrayUnion([orgRef.id]),
      }, SetOptions(merge: true));

      await batch.commit();

      _orgId = orgRef.id;
      _orgName = displayName == null || displayName.isEmpty
          ? 'Mon espace solo'
          : 'Espace de $displayName';
      notifyListeners();
    } finally {
      _setBusy = false;
    }
  }
}

