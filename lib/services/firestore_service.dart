import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/prospect.dart';
import 'workspace_scope.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<WorkspaceScope> _scope() => WorkspaceScope.resolve();

  Future<DocumentReference<Map<String, dynamic>>> _prospectRef(
      String id) async {
    final scope = await _scope();
    return scope.prospects.doc(id);
  }

  Future<DocumentReference<Map<String, dynamic>>> _planRef(
      DateTime date) async {
    final scope = await _scope();
    return scope.plans.doc(DateFormat('yyyy-MM-dd').format(date));
  }

  Future<void> addProspect(Prospect prospect) async {
    final scope = await _scope();
    final ref = prospect.id.isEmpty
        ? scope.prospects.doc()
        : scope.prospects.doc(prospect.id);
    final existing = await ref.get();
    final created = !existing.exists;
    await ref.set({
      ...prospect.toJson(),
      if (scope.isTeam) ...{
        'orgId': scope.orgId,
        'updatedBy': scope.uid,
        if (created) 'createdBy': scope.uid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (created) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      scope,
      action: created ? 'prospect_created' : 'prospect_updated',
      message: created
          ? 'Le prospect « ${prospect.name} » a été créé.'
          : 'Le prospect « ${prospect.name} » a été modifié.',
      prospectId: ref.id,
      prospectName: prospect.name,
    );
  }

  Future<void> deleteProspect(String id) async {
    final scope = await _scope();
    if (scope.isTeam) {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('deleteEnterpriseRecord')
          .call({
        'appId': kAppId,
        'orgId': scope.orgId,
        'kind': 'prospect',
        'id': id,
      });
      return;
    }
    final ref = scope.prospects.doc(id);
    final existing = await ref.get();
    final name = (existing.data()?['name'] ?? 'Prospect').toString();
    await ref.delete();
    await _logActivity(
      scope,
      action: 'prospect_deleted',
      message: 'Le prospect « $name » a été supprimé.',
      prospectId: id,
      prospectName: name,
    );
  }

  Future<List<Prospect>> loadAllProspects() async {
    final scope = await _scope();
    final snap = await scope.prospects.orderBy('name').get();
    return snap.docs
        .map((doc) => Prospect.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<void> savePlan(
    DateTime date,
    List<String> ids,
    List<Prospect> allOptions, {
    Map<String, dynamic>? smartRoute,
  }) async {
    final scope = await _scope();
    _requireAutonomousPlanning(scope);
    final planRef = scope.plans.doc(DateFormat('yyyy-MM-dd').format(date));
    await planRef.set({
      'date': date,
      'prospectIds': ids,
      'smartRoute': smartRoute ?? FieldValue.delete(),
      if (scope.isTeam) ...{
        'orgId': scope.orgId,
        'ownerUid': scope.uid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final batch = _db.batch();
    final selectedIds = ids.toSet();
    for (final prospect
        in allOptions.where((p) => selectedIds.contains(p.id))) {
      batch.set(
        scope.prospects.doc(prospect.id),
        {
          ...prospect.toJson(),
          if (scope.isTeam) ...{
            'orgId': scope.orgId,
            'updatedBy': scope.uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> replanProspect({
    required DateTime fromDate,
    required DateTime toDate,
    required String prospectId,
  }) async {
    final scope = await _scope();
    _requireAutonomousPlanning(scope);
    final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(toDate);
    final fromRef = scope.plans.doc(fromStr);
    final toRef = scope.plans.doc(toStr);
    final prospectRef = scope.prospects.doc(prospectId);

    await _db.runTransaction((tx) async {
      final fromSnap = await tx.get(fromRef);
      final toSnap = await tx.get(toRef);
      final fromData = fromSnap.data() ?? <String, dynamic>{};
      final toData = toSnap.data() ?? <String, dynamic>{};

      final fromIds = List<String>.from(fromData['prospectIds'] ?? const []);
      fromIds.removeWhere((id) => id == prospectId);
      final toIds = List<String>.from(toData['prospectIds'] ?? const []);
      if (!toIds.contains(prospectId)) toIds.add(prospectId);

      final fromUpdate = <String, dynamic>{
        'date': fromDate,
        'prospectIds': fromIds,
        if (scope.isTeam) ...{
          'orgId': scope.orgId,
          'ownerUid': scope.uid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final reports = (fromData['reports'] as Map?)?.cast<String, dynamic>();
      if (reports != null && reports.containsKey(prospectId)) {
        final report = Map<String, dynamic>.from(reports[prospectId] as Map);
        report['status'] = 'replanifie';
        report['nextVisit'] = toDate;
        report['replannedTo'] = toStr;
        reports[prospectId] = report;
        fromUpdate['reports'] = reports;
      }
      tx.set(fromRef, fromUpdate, SetOptions(merge: true));

      final replanned =
          (toData['replanned'] as Map?)?.cast<String, dynamic>() ?? {};
      replanned[prospectId] = {
        'from': fromStr,
        'at': FieldValue.serverTimestamp(),
      };
      tx.set(
        toRef,
        {
          'date': toDate,
          'prospectIds': toIds,
          'replanned': replanned,
          if (scope.isTeam) ...{
            'orgId': scope.orgId,
            'ownerUid': scope.uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      tx.set(
        prospectRef,
        {
          'prochaineVisite': toDate,
          'status': 'replanifie',
          if (scope.isTeam) 'updatedBy': scope.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    await _scheduleReminderDocuments(prospectId, toDate, scope: scope);
    final prospect = await scope.prospects.doc(prospectId).get();
    final name = (prospect.data()?['name'] ?? 'Prospect').toString();
    await _logActivity(
      scope,
      action: 'prospect_replanned',
      message: 'Le prospect « $name » a été replanifié.',
      prospectId: prospectId,
      prospectName: name,
    );
  }

  Future<List<String>> loadPlan(DateTime date) async {
    final ref = await _planRef(date);
    final doc = await ref.get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['prospectIds'] ?? const []);
  }

  /// Enregistre le reporting, met à jour la fiche prospect et crée les rappels
  /// de relance (24 h et 1 h avant la prochaine visite).
  Future<void> savePlanReport(
    DateTime date,
    List<String> ids,
    Map<String, Map<String, dynamic>> reports,
  ) async {
    final scope = await _scope();
    final planRef = scope.plans.doc(DateFormat('yyyy-MM-dd').format(date));
    final batch = _db.batch();
    batch.set(
      planRef,
      {
        'date': date,
        'prospectIds': ids,
        'reports': reports,
        if (scope.isTeam) ...{
          'orgId': scope.orgId,
          'ownerUid': scope.uid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final reminders = <MapEntry<String, DateTime>>[];
    for (final entry in reports.entries) {
      final report = entry.value;
      final nextVisit = _date(report['prochaineVisite'] ?? report['nextVisit']);
      final update = <String, dynamic>{
        if (report['status'] != null) 'status': report['status'],
        if (report['role'] != null) 'role': report['role'],
        if (report['note'] != null) 'note': report['note'],
        if (report['phone'] != null) 'phone': report['phone'],
        if (report['email'] != null) 'email': report['email'],
        if (report['finishedAt'] != null) 'finishedAt': report['finishedAt'],
        if (nextVisit != null) 'prochaineVisite': nextVisit,
        if (scope.isTeam) 'updatedBy': scope.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(
          scope.prospects.doc(entry.key), update, SetOptions(merge: true));
      if (nextVisit != null && nextVisit.isAfter(DateTime.now())) {
        reminders.add(MapEntry(entry.key, nextVisit));
      }
    }
    await batch.commit();

    if (scope.isTeam) {
      for (final entry in reports.entries) {
        final prospect = await scope.prospects.doc(entry.key).get();
        final name = (prospect.data()?['name'] ?? 'Prospect').toString();
        await _logActivity(
          scope,
          action: 'prospect_reported',
          message: 'Le compte rendu du prospect « $name » a été mis à jour.',
          prospectId: entry.key,
          prospectName: name,
        );
      }
    }

    for (final reminder in reminders) {
      await _scheduleReminderDocuments(reminder.key, reminder.value,
          scope: scope);
    }
  }

  Future<void> _scheduleReminderDocuments(
    String prospectId,
    DateTime visitAt, {
    WorkspaceScope? scope,
  }) async {
    final activeScope = scope ?? await _scope();
    final reminders = activeScope.reminders;
    final prospect = await activeScope.prospects.doc(prospectId).get();
    final prospectData = prospect.data() ?? const <String, dynamic>{};
    final oldPending = await reminders
        .where('prospectId', isEqualTo: prospectId)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _db.batch();
    for (final old in oldPending.docs) {
      batch.update(old.reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
    final offsets = <String, Duration>{
      '24h': const Duration(hours: 24),
      '1h': const Duration(hours: 1),
    };
    for (final offset in offsets.entries) {
      final dueAt = visitAt.subtract(offset.value);
      if (dueAt.isBefore(DateTime.now())) continue;
      final id =
          '${prospectId}_${visitAt.millisecondsSinceEpoch}_${offset.key}';
      batch.set(reminders.doc(id), {
        'uid': activeScope.uid,
        if (activeScope.isTeam) 'orgId': activeScope.orgId,
        'prospectId': prospectId,
        'prospectName': prospectData['name'] ?? 'Prospect',
        'address': prospectData['address'] ?? '',
        'visitAt': visitAt,
        'dueAt': dueAt,
        'kind': offset.key,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>> loadPlanData(DateTime date) async {
    final ref = await _planRef(date);
    final doc = await ref.get();
    return doc.data() ?? {};
  }

  Future<List<Prospect>> loadReportData(DateTime date) async {
    final data = await loadPlanData(date);
    final ids = List<String>.from(data['prospectIds'] ?? const []);
    if (ids.isEmpty) return [];
    final reports = Map<String, dynamic>.from(data['reports'] ?? const {});
    return _fetchProspectsByIds(ids, reports: reports);
  }

  Future<Map<DateTime, List<Prospect>>> loadAllReports() async {
    final scope = await _scope();
    final plans = await scope.plans.get();
    final result = <DateTime, List<Prospect>>{};
    for (final plan in plans.docs) {
      final parts = plan.id.split('-');
      if (parts.length != 3) continue;
      final date = DateTime.tryParse(plan.id);
      if (date == null) continue;
      final data = plan.data();
      final ids = List<String>.from(data['prospectIds'] ?? const []);
      if (ids.isEmpty) continue;
      final reports = Map<String, dynamic>.from(data['reports'] ?? const {});
      final values =
          await _fetchProspectsByIds(ids, reports: reports, scope: scope);
      if (values.isNotEmpty) result[date] = values;
    }
    return result;
  }

  Future<List<Prospect>> fetchProspectsByIds(List<String> ids) =>
      _fetchProspectsByIds(ids);

  Future<List<Prospect>> _fetchProspectsByIds(
    List<String> ids, {
    Map<String, dynamic>? reports,
    WorkspaceScope? scope,
  }) async {
    if (ids.isEmpty) return [];
    final activeScope = scope ?? await _scope();
    final result = <Prospect>[];

    // Firestore limite les requêtes whereIn : on conserve les paquets de 10,
    // mais on en exécute au maximum 3 en parallèle. Une grosse tournée ne
    // bloque donc plus inutilement chaque paquet derrière le précédent, sans
    // lancer une rafale incontrôlée de lectures.
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      final end = (i + 10 < ids.length) ? i + 10 : ids.length;
      chunks.add(ids.sublist(i, end));
    }

    for (var offset = 0; offset < chunks.length; offset += 3) {
      final end = (offset + 3 < chunks.length) ? offset + 3 : chunks.length;
      final wave = chunks.sublist(offset, end);
      final snapshots = await Future.wait(
        wave.map(
          (chunk) => activeScope.prospects
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        ),
      );

      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final merged = Map<String, dynamic>.from(doc.data());
          final report =
              Map<String, dynamic>.from(reports?[doc.id] ?? const {});
          merged.addAll({
            if (report['phone'] != null) 'phone': report['phone'],
            if (report['email'] != null) 'email': report['email'],
            if (report['status'] != null) 'status': report['status'],
            if (report['role'] != null) 'role': report['role'],
            if (report['note'] != null) 'note': report['note'],
            if (report['prochaineVisite'] != null)
              'prochaineVisite': report['prochaineVisite'],
            if (report['nextVisit'] != null) 'nextVisit': report['nextVisit'],
            if (report['finishedAt'] != null)
              'finishedAt': report['finishedAt'],
          });
          result.add(Prospect.fromFirestore(merged, doc.id));
        }
      }
    }

    // Evite ids.indexOf(...) dans le comparateur (O(n²) sur les grandes listes).
    final order = <String, int>{
      for (var i = 0; i < ids.length; i++) ids[i]: i,
    };
    result.sort((a, b) =>
        (order[a.id] ?? ids.length).compareTo(order[b.id] ?? ids.length));
    return result;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _logActivity(
    WorkspaceScope scope, {
    required String action,
    required String message,
    String? prospectId,
    String? prospectName,
  }) async {
    if (!scope.isTeam) return;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      await scope.activity.add({
        'action': action,
        'message': message,
        'actorUid': scope.uid,
        'actorEmail': email,
        'targetUid': null,
        if (prospectId != null) 'prospectId': prospectId,
        if (prospectName != null) 'prospectName': prospectName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // L'action métier reste prioritaire si l'historique est momentanément
      // indisponible. Les règles Firebase empêchent toute usurpation d'auteur.
    }
  }

  void _requireAutonomousPlanning(WorkspaceScope scope) {
    if (scope.isTeam && !scope.canPlanAutonomously) {
      throw StateError(
        'Votre responsable commercial doit activer l’autonomie avant que vous puissiez créer ou modifier une tournée.',
      );
    }
  }
}
