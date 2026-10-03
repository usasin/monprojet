import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'sales_model.dart';

class SalesService {
  SalesService(
    this.orgId, {
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = firebaseAuth ?? FirebaseAuth.instance;
  final String orgId;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  bool get isPersonal => orgId.isEmpty;
  DocumentReference<Map<String, dynamic>> get org => isPersonal
      ? db.collection('users').doc(auth.currentUser!.uid)
      : db.collection('apps').doc(kAppId).collection('orgs').doc(orgId);
  CollectionReference<Map<String, dynamic>> deals(String uid) => isPersonal
      ? org.collection('opportunities')
      : org.collection('memberData').doc(uid).collection('opportunities');
  Future<List<SalesDeal>> load(List<Map<String, String>> members) async {
    final result = <SalesDeal>[];
    // Bounded parallelism, every page read; no silent 100/500-record truncation.
    for (var offset = 0; offset < members.length; offset += 4) {
      final batch = members.skip(offset).take(4);
      final rows = await Future.wait(
        batch.map((m) async {
          final list = <SalesDeal>[];
          QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
          while (true) {
            Query<Map<String, dynamic>> query = deals(
              m['uid']!,
            ).orderBy(FieldPath.documentId);
            if (cursor != null) query = query.startAfterDocument(cursor);
            query = query.limit(200);
            final snap = await query.get(
              const GetOptions(source: Source.server),
            );
            list.addAll(
              snap.docs
                  .where((d) => d.data()['deletedAt'] == null)
                  .map(
                    (d) => SalesDeal.fromMap(
                      d.id,
                      m['uid']!,
                      m['name']!,
                      d.data(),
                    ),
                  ),
            );
            if (snap.docs.length < 200) break;
            cursor = snap.docs.last;
          }
          return list;
        }),
      );
      for (final list in rows) {
        result.addAll(list);
      }
    }
    return result;
  }

  Future<SalesDeal?> currentDeal(String id) async {
    final uid = auth.currentUser!.uid;
    final snap = await deals(
      uid,
    ).doc(id).get(const GetOptions(source: Source.server));
    return snap.exists && snap.data()?['deletedAt'] == null
        ? SalesDeal.fromMap(id, uid, 'Moi', snap.data()!)
        : null;
  }

  String newId() => deals(auth.currentUser!.uid).doc().id;
  String draftKey(String id) =>
      'sales-draft:$orgId:${auth.currentUser!.uid}:$id';
  Future<void> saveDraft(String id, Map<String, dynamic> values) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      draftKey(id),
      jsonEncode(values),
    );
    if (!ok) throw StateError('Brouillon non enregistré');
  }

  Future<Map<String, dynamic>?> draft(String id) async {
    final raw = (await SharedPreferences.getInstance()).getString(draftKey(id));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft(String id) async {
    await (await SharedPreferences.getInstance()).remove(draftKey(id));
  }

  Future<void> save(String id, Map<String, dynamic> values) async {
    await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('saveSalesOpportunity').call({
      'appId': kAppId,
      'workspace': isPersonal ? 'personal' : 'team',
      if (!isPersonal) 'orgId': orgId,
      'opportunityId': id,
      ...values,
    });
    await clearDraft(id);
  }
}
