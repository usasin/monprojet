// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/prospect.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /* ───────────────────────── Prospects ───────────────────────── */

  /// Enregistre un nouveau prospect
  Future<void> addProspect(Prospect prospect) async {
    final docRef = _db
        .collection('users').doc(_uid)
        .collection('prospects').doc();

    await docRef.set({
      'name'    : prospect.name,
      'address' : prospect.address,
      'lat'     : prospect.lat,
      'lng'     : prospect.lng,
      'category': prospect.category,
      if (prospect.phone != null) 'phone' : prospect.phone,
      if (prospect.email != null) 'email' : prospect.email,
    });
  }

  /// Supprime un prospect (par son ID) de Firestore
  Future<void> deleteProspect(String id) async {
    await _db
        .collection('users').doc(_uid)
        .collection('prospects').doc(id)
        .delete();
  }

  /* ───────────────────────── Plans (daily) ───────────────────────── */

  /// Sauvegarde le plan + détails des prospects
  Future<void> savePlan(
      DateTime date,
      List<String> ids,
      List<Prospect> allOptions,
      ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final planRef = _db
        .collection('users').doc(_uid)
        .collection('plans').doc(dateStr);

    // 1) la liste d’IDs
    await planRef.set({
      'date'       : date,
      'prospectIds': ids,
    });

    // 2) détails des prospects (merge)
    final batch = _db.batch();
    for (final p in allOptions.where((p) => ids.contains(p.id))) {
      final docRef = _db
          .collection('users').doc(_uid)
          .collection('prospects').doc(p.id);

      batch.set(docRef, {
        'name'    : p.name,
        'address' : p.address,
        'lat'     : p.lat,
        'lng'     : p.lng,
        'category': p.category,
        if (p.phone != null) 'phone': p.phone,
        if (p.email != null) 'email': p.email,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Charge uniquement la liste d’IDs pour une date
  Future<List<String>> loadPlan(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final doc = await _db
        .collection('users').doc(_uid)
        .collection('plans').doc(dateStr)
        .get();

    if (!doc.exists) return [];
    return List<String>.from(doc.data()!['prospectIds'] ?? []);
  }

  /* ───────────────────────── Reporting (terminés) ───────────────────────── */

  /// Sauvegarde le reporting détaillé pour un jour
  Future<void> savePlanReport(
      DateTime date,
      List<String> ids,
      Map<String, Map<String, dynamic>> reports,
      ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await _db
        .collection('users').doc(_uid)
        .collection('plans').doc(dateStr)
        .set({
      'date'       : date,
      'prospectIds': ids,
      'reports'    : reports,
    });
  }

  /// Charge les données brutes d’un plan (ids + reports)
  Future<Map<String, dynamic>> loadPlanData(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final doc = await _db
        .collection('users').doc(_uid)
        .collection('plans').doc(dateStr)
        .get();

    if (!doc.exists) return {};
    return doc.data()!;
  }

  /// Charge les prospects terminés pour **une seule** date (fusion ids + reports)
  Future<List<Prospect>> loadReportData(DateTime date) async {
    final planData = await loadPlanData(date);
    if (planData.isEmpty) return [];

    final ids     = List<String>.from(planData['prospectIds'] ?? []);
    final reports = Map<String, dynamic>.from(planData['reports'] ?? {});
    if (ids.isEmpty) return [];

    return _fetchProspectsByIds(ids, reports);
  }

  /* ───────────────────────── Tous les reports ───────────────────────── */

  /// Regroupe tous les prospects terminés, par date.
  Future<Map<DateTime, List<Prospect>>> loadAllReports() async {
    final plansSnap = await _db
        .collection('users').doc(_uid)
        .collection('plans')
        .get();

    final Map<DateTime, List<Prospect>> res = {};

    for (final plan in plansSnap.docs) {
      final parts = plan.id.split('-');
      if (parts.length != 3) continue;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      final data    = plan.data();
      final ids     = List<String>.from(data['prospectIds'] ?? []);
      final reports = Map<String, dynamic>.from(data['reports'] ?? {});
      if (ids.isEmpty) continue;

      final prospects = await _fetchProspectsByIds(ids, reports);
      if (prospects.isNotEmpty) res[date] = prospects;
    }
    return res;
  }

  /* ───────────────────────── Helpers privés ───────────────────────── */

  /// Public wrapper pour récupérer des prospects par leurs IDs
  Future<List<Prospect>> fetchProspectsByIds(List<String> ids) =>
      _fetchProspectsByIds(ids);

  /// Firestore limite `whereIn` à 10 IDs ; on segmente si besoin.
  Future<List<Prospect>> _fetchProspectsByIds(
      List<String> ids, [
        Map<String, dynamic>? reports,
      ]) async {
    final List<Prospect> result = [];

    DateTime? _ts(dynamic v) => v == null ? null : (v as Timestamp).toDate();

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final snap = await _db
          .collection('users').doc(_uid)
          .collection('prospects')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final d in snap.docs) {
        final m  = d.data();
        final rp = Map<String, dynamic>.from(reports?[d.id] ?? {});

        result.add(Prospect(
          id      : d.id,
          name    : m['name']    ?? '',
          address : m['address'] ?? '',
          lat     : (m['lat'] as num).toDouble(),
          lng     : (m['lng'] as num).toDouble(),
          category: m['category'] ?? '',

          phone   : rp['phone']   ?? m['phone'],
          email   : rp['email']   ?? m['email'],
          status  : rp['status']  ?? m['status'],
          role    : rp['role']    ?? m['role'],
          note    : rp['note']    ?? m['note'],

          prochaineVisite : _ts(rp['prochaineVisite'] ?? rp['nextVisit']),
          finishedAt      : _ts(rp['finishedAt']),
        ));
      }
    }
    return result;
  }
}
