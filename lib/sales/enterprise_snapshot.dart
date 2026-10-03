import '../models/prospect.dart';
import 'enterprise_display.dart';
import '../models/route_metrics.dart';
import 'sales_model.dart';

class EnterpriseMember {
  const EnterpriseMember(
    this.uid,
    this.name,
    this.role,
    this.managerUid,
    this.active,
  );
  final String uid, name, role, managerUid;
  final bool active;
  factory EnterpriseMember.fromMap(String uid, Map<String, dynamic> d) {
    final full = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    return EnterpriseMember(
      uid,
      full.isEmpty ? '${d['displayName'] ?? d['email'] ?? 'Membre'}' : full,
      '${d['role'] ?? ''}',
      '${d['managerUid'] ?? ''}',
      d['status'] == 'active',
    );
  }
}

class EnterpriseProspect {
  const EnterpriseProspect(this.prospect, this.createdAt, this.createdBy);
  final Prospect prospect;
  final DateTime? createdAt;
  final String createdBy;
  factory EnterpriseProspect.fromMap(String id, Map<String, dynamic> d) =>
      EnterpriseProspect(
        Prospect.fromFirestore(d, id),
        salesDate(d['createdAt']),
        '${d['createdBy'] ?? ''}',
      );
}

class EnterpriseRecord {
  const EnterpriseRecord(this.id, this.ownerUid, this.data);
  final String id, ownerUid;
  final Map<String, dynamic> data;
  DateTime? get date => salesDate(data['date'] ?? data['startsAt']);
  Set<String> get prospectIds =>
      Set<String>.from(data['prospectIds'] ?? const []);
  int get completedVisits {
    final reports = Map<String, dynamic>.from(data['reports'] ?? const {});
    return prospectIds
        .where((id) => RouteMetrics.hasReport(reports[id]))
        .length;
  }

  bool get complete =>
      prospectIds.isNotEmpty && completedVisits == prospectIds.length;
}

class EnterpriseSnapshot {
  const EnterpriseSnapshot({
    required this.members,
    required this.prospects,
    required this.deals,
    required this.plans,
    required this.appointments,
    required this.invites,
    required this.readAt,
    this.display = const EnterpriseDisplaySettings(),
    this.managerUid,
  });
  final List<EnterpriseMember> members;
  final List<EnterpriseProspect> prospects;
  final List<SalesDeal> deals;
  final List<EnterpriseRecord> plans, appointments, invites;
  final DateTime readAt;
  final EnterpriseDisplaySettings display;
  final String? managerUid;
  EnterpriseView view(
    SalesWindow window,
    DateTime now, {
    String scope = 'all',
  }) => EnterpriseView(this, window, now, scope);
}

/// Stock (prospects/current follow-up) and results during a period remain distinct.
/// Shared prospects are unique by document id; multiple deals never inflate them.
class EnterpriseView {
  EnterpriseView(this.snapshot, this.window, this.now, this.scope) {
    final reps = snapshot.members.where((m) => m.role == 'REP');
    selectedMembers = reps
        .where(
          (m) =>
              scope == 'all' ||
              (scope.startsWith('manager:') &&
                  m.managerUid == scope.substring(8)) ||
              (scope.startsWith('member:') && m.uid == scope.substring(7)) ||
              (scope == 'unassigned' &&
                  !snapshot.members.any(
                    (n) => n.uid == m.managerUid && n.role == 'MANAGER',
                  )),
        )
        .toList();
    final uids = selectedMembers.map((m) => m.uid).toSet();
    deals = snapshot.deals.where((d) => uids.contains(d.ownerUid)).toList();
    final linked = deals.map((d) => d.prospectId).toSet();
    // Without a filter, include every shared prospect, even an orphan/legacy entry.
    prospects = snapshot.prospects
        .where(
          (p) =>
              scope == 'all' ||
              uids.contains(p.createdBy) ||
              linked.contains(p.prospect.id),
        )
        .toList();
    plans = snapshot.plans
        .where(
          (p) =>
              uids.contains(p.ownerUid) &&
              window.contains(p.date) &&
              p.prospectIds.isNotEmpty,
        )
        .toList();
    appointments = snapshot.appointments
        .where(
          (p) =>
              uids.contains(p.ownerUid) &&
              window.contains(p.date) &&
              p.data['status'] != 'cancelled',
        )
        .toList();
    totals = SalesTotals(deals, window, now);
  }
  final EnterpriseSnapshot snapshot;
  final SalesWindow window;
  final DateTime now;
  final String scope;
  late final List<EnterpriseMember> selectedMembers;
  late final List<EnterpriseProspect> prospects;
  late final List<SalesDeal> deals;
  late final List<EnterpriseRecord> plans, appointments;
  late final SalesTotals totals;
  late final Set<String> hotIds = deals
      .where((d) => d.open && d.interest == 'hot')
      .map((d) => d.prospectId)
      .toSet();
  late final Set<String> followUpIds = deals
      .where(
        (d) => d.open && d.nextAction == 'followup' && d.nextActionAt != null,
      )
      .map((d) => d.prospectId)
      .toSet();
  late final Set<String> qualifyIds = _qualifyIds();
  Set<String> _qualifyIds() {
    final withDeals = deals.map((d) => d.prospectId).toSet();
    final qualify = deals
        .where((d) => d.open && d.stage == 'qualify')
        .map((d) => d.prospectId)
        .toSet();
    return prospects
        .where(
          (p) =>
              !withDeals.contains(p.prospect.id) ||
              qualify.contains(p.prospect.id),
        )
        .map((p) => p.prospect.id)
        .toSet();
  }

  List<EnterpriseProspect> prospectsFor(String filter) => prospects.where((p) {
    switch (filter) {
      case 'new':
        return window.contains(p.createdAt);
      case 'qualify':
        return qualifyIds.contains(p.prospect.id);
      case 'hot':
        return hotIds.contains(p.prospect.id);
      case 'followup':
        return followUpIds.contains(p.prospect.id);
      case 'won':
        return totals.won.any((d) => d.prospectId == p.prospect.id);
      default:
        return true;
    }
  }).toList();
  int get plannedVisits => plans.fold(0, (n, p) => n + p.prospectIds.length);
  int get completedVisits => plans.fold(0, (n, p) => n + p.completedVisits);
  int get completedTours => plans.where((p) => p.complete).length;
  List<SalesDeal> get overdueFollowUps =>
      totals.overdue.where((d) => d.nextAction == 'followup').toList();
  List<EnterpriseRecord> get pendingInvites => snapshot.invites
      .where(
        (i) =>
            i.data['active'] == true &&
            (salesDate(i.data['expiresAt'])?.isAfter(now) ?? false),
      )
      .toList();
  List<EnterpriseMember> get activeMembers {
    final ids = <String>{
      ...plans.map((p) => p.ownerUid),
      ...appointments.map((p) => p.ownerUid),
      ...deals
          .where(
            (d) =>
                window.contains(d.createdAt) ||
                window.contains(d.updatedAt) ||
                window.contains(d.closedAt),
          )
          .map((d) => d.ownerUid),
    };
    return selectedMembers
        .where((m) => m.active && ids.contains(m.uid))
        .toList();
  }

  List<SalesDeal> dealsFor(String prospectId) =>
      deals.where((d) => d.prospectId == prospectId).toList();
  String nameFor(String uid) =>
      snapshot.members.where((m) => m.uid == uid).firstOrNull?.name ??
      'Ancien membre';
}
