import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'enterprise_snapshot.dart';
import 'enterprise_display.dart';
import 'sales_model.dart';
import 'sales_service.dart';

class EnterpriseRepository {
  EnterpriseRepository(
    this.orgId, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;
  final String orgId;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  DocumentReference<Map<String, dynamic>> get root =>
      db.collection('apps').doc(kAppId).collection('orgs').doc(orgId);

  /// All pages, document-id ordering also includes legacy prospects without names.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _pages(
    Query<Map<String, dynamic>> query,
  ) async {
    final rows = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var page = query.orderBy(FieldPath.documentId);
      if (cursor != null) page = page.startAfterDocument(cursor);
      page = page.limit(200);
      final snap = await page.get(const GetOptions(source: Source.server));
      rows.addAll(snap.docs);
      if (snap.docs.length < 200) return rows;
      cursor = snap.docs.last;
    }
  }

  Future<EnterpriseSnapshot> load(SalesWindow window) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || orgId.isEmpty)
      throw StateError('Session entreprise requise');
    final me = await root
        .collection('members')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (!['OWNER', 'MANAGER'].contains(me.data()?['role']) ||
        me.data()?['status'] != 'active') {
      throw StateError('Accès administrateur requis');
    }
    final manager = me.data()?['role'] == 'MANAGER';
    final organization = await root.get(
      const GetOptions(source: Source.server),
    );
    final basic = await Future.wait([
      _pages(
        manager
            ? root
                .collection('members')
                .where('role', isEqualTo: 'REP')
                .where('managerUid', isEqualTo: uid)
            : root.collection('members'),
      ),
      _pages(root.collection('prospects')),
      manager
          ? Future.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[])
          : _pages(root.collection('invites').where('active', isEqualTo: true)),
    ]);
    final members =
        basic[0].map((d) => EnterpriseMember.fromMap(d.id, d.data())).toList();
    if (manager) members.add(EnterpriseMember.fromMap(uid, me.data()!));
    final reps = members.where((m) => m.role == 'REP').toList();
    final plans = <EnterpriseRecord>[], appointments = <EnterpriseRecord>[];
    // Bounded parallelism for organizations with many representatives.
    for (var offset = 0; offset < reps.length; offset += 4) {
      final batches = await Future.wait(
        reps.skip(offset).take(4).map((m) async {
          final ref = root.collection('memberData').doc(m.uid);
          // Range queries only on one field, without extra orderBy/composite indexes.
          Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> period(
            String kind,
            String field,
          ) async {
            final query = ref
                .collection(kind)
                .where(
                  field,
                  isGreaterThanOrEqualTo: Timestamp.fromDate(window.start),
                )
                .where(field, isLessThan: Timestamp.fromDate(window.end));
            // The selected window is bounded; all documents are read, no limit truncation.
            return (await query.get(
              const GetOptions(source: Source.server),
            ))
                .docs;
          }

          final rows = await Future.wait([
            period('plans', 'date'),
            period('appointments', 'startsAt'),
          ]);
          return (
            rows[0]
                .map((d) => EnterpriseRecord(d.id, m.uid, d.data()))
                .toList(),
            rows[1]
                .map((d) => EnterpriseRecord(d.id, m.uid, d.data()))
                .toList(),
          );
        }),
      );
      for (final batch in batches) {
        plans.addAll(batch.$1);
        appointments.addAll(batch.$2);
      }
    }
    final deals =
        await SalesService(orgId, firestore: db, firebaseAuth: auth).load([
      for (final m in reps) {'uid': m.uid, 'name': m.name},
    ]);
    return EnterpriseSnapshot(
      members: members,
      prospects: basic[1]
          .map((d) => EnterpriseProspect.fromMap(d.id, d.data()))
          .toList(),
      deals: deals,
      plans: plans,
      appointments: appointments,
      invites:
          basic[2].map((d) => EnterpriseRecord(d.id, '', d.data())).toList(),
      readAt: DateTime.now(),
      display: EnterpriseDisplaySettings.fromMap(
        organization.data()?['displaySettings'],
      ),
      managerUid: manager ? uid : null,
    );
  }
}

class EnterpriseController extends ChangeNotifier {
  EnterpriseController(this.repository, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final EnterpriseRepository repository;
  final DateTime Function() clock;
  String period = 'week', scope = 'all';
  EnterpriseSnapshot? snapshot;
  bool loading = false;
  String? error;
  int _revision = 0;
  bool _disposed = false;
  SalesWindow get window => SalesWindow.forPeriod(clock(), period);
  EnterpriseView? get view => snapshot?.view(window, clock(), scope: scope);
  Future<void> refresh() async {
    final revision = ++_revision;
    loading = true;
    error = null;
    snapshot = null;
    notifyListeners();
    try {
      final next = await repository.load(window);
      if (_disposed || revision != _revision) return;
      snapshot = next;
      if (next.managerUid != null && scope == 'all')
        scope = 'manager:${next.managerUid}';
      if (!scopeOptions(next).containsKey(scope))
        scope = next.managerUid == null ? 'all' : 'manager:${next.managerUid}';
    } catch (_) {
      if (_disposed || revision != _revision) return;
      error = 'Vue entreprise indisponible. Réessayez.';
    }
    loading = false;
    notifyListeners();
  }

  void selectPeriod(String value) {
    if (period == value) return;
    period = value;
    refresh();
  }

  void selectScope(String value) {
    scope = value;
    notifyListeners();
  }

  static Map<String, String> scopeOptions(EnterpriseSnapshot data) => {
        if (data.managerUid == null) 'all': 'Toutes les équipes',
        for (final m in data.members.where((m) => m.role == 'MANAGER'))
          'manager:${m.uid}': 'Équipe · ${m.name}',
        if (data.managerUid == null) 'unassigned': 'Sans responsable',
        for (final m in data.members.where((m) => m.role == 'REP'))
          'member:${m.uid}': 'Commercial · ${m.name}',
      };
  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
