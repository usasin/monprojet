// lib/services/org_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart'; // kAppId

class OrgService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final String appId;
  OrgService(this.appId);

  DocumentReference<Map<String, dynamic>> orgRef(String orgId) =>
      db.collection('apps').doc(appId).collection('orgs').doc(orgId);

  CollectionReference<Map<String, dynamic>> _orgsCol() =>
      db.collection('apps').doc(appId).collection('orgs');

  DocumentReference<Map<String, dynamic>> _licenseRef(String code) =>
      db.collection('apps').doc(appId).collection('orgLicenses').doc(code);

  // ------------------------------
  // PRECHECK : vérifie la licence
  // ------------------------------
  Future<String> precheckActivationCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) throw 'Code requis';

    final snap = await _licenseRef(code).get();
    if (!snap.exists) throw 'Code d’activation introuvable';

    final data = snap.data()!;
    final bool active = (data['active'] == true);
    final bool used = (data['used'] == true);
    final Timestamp? ts = data['expiresAt'] as Timestamp?;
    final DateTime? expiresAt = ts?.toDate();

    if (!active) throw 'Code inactif';
    if (used) throw 'Code déjà utilisé';
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw 'Code expiré';
    }
    return (data['plan'] ?? 'STANDARD').toString();
  }

  // ------------------------------
  // Création AVEC licence
  // ------------------------------
  Future<Map<String, String>> createOrgWithActivation({
    required String ownerUid,
    required String ownerEmail,
    required String name,
    required String activationCode,
  }) async {
    activationCode = activationCode.trim().toUpperCase();
    if (activationCode.isEmpty) throw 'Code d’activation requis';

    return await db.runTransaction<Map<String, String>>((tx) async {
      final licRef = _licenseRef(activationCode);
      final licSnap = await tx.get(licRef);

      if (!licSnap.exists) throw 'Code d’activation introuvable';

      final data = licSnap.data() as Map<String, dynamic>;
      final bool active = (data['active'] == true);
      final bool used = (data['used'] == true);
      final Timestamp? ts = data['expiresAt'] as Timestamp?;
      final DateTime? expiresAt = ts?.toDate();

      if (!active) throw 'Code inactif';
      if (used) throw 'Code déjà utilisé';
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw 'Code expiré';
      }

      final plan = data['plan'] ?? 'STANDARD';

      final orgDoc = _orgsCol().doc();
      tx.set(orgDoc, {
        'name': name,
        'ownerUid': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'plan': plan,
        'activatedByCode': activationCode,
      });

      tx.set(orgDoc.collection('members').doc(ownerUid), {
        'uid': ownerUid,
        'role': 'OWNER',
        'email': ownerEmail,
        'displayName': ownerEmail,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      tx.update(licRef, {
        'active': false,
        'used': true,
        'usedAt': FieldValue.serverTimestamp(),
        'orgId': orgDoc.id,
        'usedByUid': ownerUid,
      });

      return {'orgId': orgDoc.id, 'orgName': name, 'role': 'OWNER'};
    });
  }

  // ------------------------------
  // Invitations (membres)
  // ------------------------------
  Future<String> createInvite({
    required String orgId,
    String role = 'REP',
    String? email,
    String? requesterUid,
    String? requesterEmail,
  }) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();

    final inviteRef = orgRef(orgId).collection('invites').doc(code);
    await inviteRef.set({
      'role': role,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'active': true,
      if (requesterUid != null) 'requesterUid': requesterUid,
      if (requesterEmail != null) 'requesterEmail': requesterEmail,
    });
    return code;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> invites(String orgId) {
    return orgRef(orgId)
        .collection('invites')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> requestResend({
    required String code,
    String? requesterUid,
    String? requesterEmail,
  }) async {
    await db
        .collection('apps')
        .doc(appId)
        .collection('inviteResendRequests')
        .add({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      if (requesterUid != null) 'requesterUid': requesterUid,
      if (requesterEmail != null) 'requesterEmail': requesterEmail,
    });
  }

  Future<Map<String, String>> acceptInvite({
    required String code,
    required String uid,
    required String email,
  }) async {
    final snap = await db
        .collectionGroup('invites')
        .where(FieldPath.documentId, isEqualTo: code)
        .get();

    if (snap.docs.isEmpty) throw 'Invitation introuvable';

    final d = snap.docs.first;
    final data = d.data();
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt) || data['active'] != true) {
      throw 'Invitation expirée';
    }

    final segments = d.reference.path.split('/');
    final orgId = segments[3];

    await d.reference.parent.parent!.collection('members').doc(uid).set({
      'uid': uid,
      'role': data['role'] ?? 'REP',
      'email': email,
      'displayName': email,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await d.reference.update({'active': false});

    final orgDoc = await d.reference.parent.parent!.get();
    return {
      'orgId': orgId,
      'orgName': (orgDoc.data() as Map)['name'] ?? 'Mon entreprise',
      'role': data['role'] ?? 'REP',
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> members(String orgId) =>
      orgRef(orgId).collection('members').snapshots();

  Future<void> removeMember(String orgId, String uid) async {
    await orgRef(orgId).collection('members').doc(uid).delete();
  }

  // ------------------------------
  // Renvoi code d’activation (après paiement)
  // ------------------------------
  Future<void> requestActivationResend({
    String? email,
    String? orderId,
    String? requesterUid,
    String? requesterEmail,
  }) async {
    if ((email == null || email.trim().isEmpty) &&
        (orderId == null || orderId.trim().isEmpty)) {
      throw 'Renseignez un email ou un numéro de commande';
    }
    await db
        .collection('apps')
        .doc(appId)
        .collection('activationResendRequests')
        .add({
      'email': email?.trim(),
      'orderId': orderId?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (requesterUid != null) 'requesterUid': requesterUid,
      if (requesterEmail != null) 'requesterEmail': requesterEmail,
    });
  }
}
