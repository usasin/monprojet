import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/route_metrics.dart';

class MemberMetrics {
  MemberMetrics(
    this.uid,
    this.name,
    this.active,
    this.today,
    this.week,
    this.appointments,
    this.todayAppointments,
    this.prospects,
    this.followUps,
    this.nextVisit,
    this.nextAppointment,
  );
  final String uid, name;
  final bool active;
  final RouteMetrics today, week;
  final int appointments, todayAppointments, prospects, followUps;
  final String? nextVisit, nextAppointment;
}

class EnterpriseMetricsService {
  static DateTime weekStart(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final db = FirebaseFirestore.instance;

  Future<List<MemberMetrics>> load(
    String orgId,
    String role,
    String uid,
  ) async {
    final org = db.collection('apps').doc(kAppId).collection('orgs').doc(orgId);
    Query<Map<String, dynamic>> members = org.collection('members');
    if (role == 'MANAGER')
      members = members
          .where('managerUid', isEqualTo: uid)
          .where('role', isEqualTo: 'REP');
    if (role == 'REP')
      members = members.where(FieldPath.documentId, isEqualTo: uid);
    final memberDocs = await members.get();
    final now = DateTime.now();
    final start = weekStart(now);
    final end = start.add(const Duration(days: 7));
    final today = DateTime(now.year, now.month, now.day);
    final prospects = await org
        .collection('prospects')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final reps = memberDocs.docs.where((d) => d.data()['role'] == 'REP');
    final result = <MemberMetrics>[];
    for (final member in reps) {
      final data = member.data();
      final root = org.collection('memberData').doc(member.id);
      final snapshots = await Future.wait([
        root
            .collection('plans')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end))
            .get(),
        root
            .collection('appointments')
            .where(
              'startsAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('startsAt', isLessThan: Timestamp.fromDate(end))
            .get(),
        root
            .collection('reminders')
            .where('visitAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
            .get(),
      ]);
      final dayPlans = snapshots[0].docs
          .where((d) {
            final date = (d.data()['date'] as Timestamp).toDate();
            return date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
          })
          .map((d) => d.data())
          .toList();
      final appointments = snapshots[1].docs
          .where((d) => d.data()['status'] != 'cancelled')
          .toList();
      final dayAppointments =
          appointments.where((d) {
            final date = (d.data()['startsAt'] as Timestamp).toDate();
            return date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
          }).toList()..sort(
            (a, b) => (a.data()['startsAt'] as Timestamp).compareTo(
              b.data()['startsAt'] as Timestamp,
            ),
          );
      String? nextVisit;
      for (final plan in dayPlans) {
        final reports = Map<String, dynamic>.from(plan['reports'] ?? {});
        for (final id in List<String>.from(plan['prospectIds'] ?? [])) {
          if (!RouteMetrics.hasReport(reports[id])) {
            final prospect = await org.collection('prospects').doc(id).get();
            nextVisit = prospect.data()?['name']?.toString() ?? 'Prospect';
            break;
          }
        }
        if (nextVisit != null) break;
      }
      final next = dayAppointments
          .where(
            (d) => (d.data()['startsAt'] as Timestamp).toDate().isAfter(now),
          )
          .firstOrNull;
      final reminders = snapshots[2].docs.where(
        (d) =>
            d.data()['status'] == 'pending' &&
            (d.data()['visitAt'] as Timestamp).toDate().isBefore(end),
      );
      final followUps = reminders
          .map(
            (d) =>
                '${d.data()['prospectId']}_${(d.data()['visitAt'] as Timestamp).millisecondsSinceEpoch}',
          )
          .toSet()
          .length;
      result.add(
        MemberMetrics(
          member.id,
          (data['displayName'] ?? data['email'] ?? 'Commercial').toString(),
          data['status'] == 'active',
          RouteMetrics.fromPlans(dayPlans),
          RouteMetrics.fromPlans(snapshots[0].docs.map((d) => d.data())),
          appointments.length,
          dayAppointments.length,
          prospects.docs
              .where((d) => d.data()['createdBy'] == member.id)
              .length,
          followUps,
          nextVisit,
          next?.data()['title']?.toString(),
        ),
      );
    }
    return result;
  }
}
