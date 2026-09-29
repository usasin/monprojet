import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/prospect.dart';
import 'workspace_scope.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<User?>? _authSub;

  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) await _saveCurrentToken(user.uid);
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _saveCurrentToken(user.uid);
    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _saveToken(uid, token);
    });
  }

  Future<void> _saveCurrentToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) await _saveToken(uid, token);
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': {token: FieldValue.serverTimestamp()},
      'lastDeviceSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> scheduleFollowUp({
    required Prospect prospect,
    required DateTime visitAt,
  }) async {
    final scope = await WorkspaceScope.resolve();
    final uid = scope.uid;
    final reminders = scope.reminders;

    final normalized = visitAt.toLocal();
    final events = <String, DateTime>{
      '24h': normalized.subtract(const Duration(hours: 24)),
      '1h': normalized.subtract(const Duration(hours: 1)),
    };
    final batch = FirebaseFirestore.instance.batch();
    for (final entry in events.entries) {
      if (entry.value.isBefore(DateTime.now())) continue;
      final id = '${prospect.id}_${normalized.millisecondsSinceEpoch}_${entry.key}';
      batch.set(reminders.doc(id), {
        'uid': uid,
        if (scope.isTeam) 'orgId': scope.orgId,
        'prospectId': prospect.id,
        'prospectName': prospect.name,
        'address': prospect.address,
        'visitAt': Timestamp.fromDate(normalized),
        'dueAt': Timestamp.fromDate(entry.value),
        'kind': entry.key,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> cancelForProspect(String prospectId) async {
    final scope = await WorkspaceScope.resolve();
    final snap = await scope.reminders
        .where('prospectId', isEqualTo: prospectId)
        .where('status', isEqualTo: 'pending')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'cancelled'});
    }
    await batch.commit();
  }

  void dispose() {
    _tokenSub?.cancel();
    _authSub?.cancel();
  }
}
