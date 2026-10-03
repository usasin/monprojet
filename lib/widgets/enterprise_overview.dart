import 'dart:async';
import '../services/org_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/org_provider.dart';
import '../services/enterprise_metrics_service.dart';
import 'reporting_charts.dart';
import '../theme/prospecto_colors.dart';

/// Shared by the home and cockpit; role and organization changes reset the data.
class EnterpriseOverview extends StatefulWidget {
  const EnterpriseOverview({super.key, this.weekly = false});
  final bool weekly;
  @override
  State<EnterpriseOverview> createState() => _EnterpriseOverviewState();
}

class _EnterpriseOverviewState extends State<EnterpriseOverview> {
  String? _scope;
  String? _membershipSignature;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membershipWatch;
  Future<List<MemberMetrics>>? _future;
  void _load(OrgProvider org) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || org.orgId == null) return;
    _future = EnterpriseMetricsService().load(
      org.orgId!,
      org.role ?? 'REP',
      uid,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final org = context.watch<OrgProvider>();
    final scope =
        '${org.orgId}:${org.role}:${FirebaseAuth.instance.currentUser?.uid}';
    if (_scope != scope) {
      _scope = scope;
      _load(org);
      _membershipWatch?.cancel();
      _membershipSignature = null;
      _membershipWatch = OrgService(kAppId)
          .allMembers(
        org.orgId!,
        role: org.role,
        uid: FirebaseAuth.instance.currentUser?.uid,
      )
          .listen(
        (snap) {
          final signature = snap.docs
              .map(
                (d) =>
                    '${d.id}:${d.data()['role']}:${d.data()['status']}:${d.data()['managerUid']}',
              )
              .join('|');
          final changed =
              _membershipSignature != null && _membershipSignature != signature;
          _membershipSignature = signature;
          if (changed && mounted)
            setState(() => _load(context.read<OrgProvider>()));
        },
        onError: (_) {
          if (mounted) setState(() => _load(context.read<OrgProvider>()));
        },
      );
    }
  }

  @override
  void dispose() {
    _membershipWatch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    if (!org.isTeam) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.weekly
                        ? 'KPI semaine'
                        : org.canManageTeam
                            ? 'Aujourd’hui'
                            : 'Ma journée',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: () => setState(() => _load(org)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (org.isOwner && !widget.weekly) _OwnerCounts(org: org),
            FutureBuilder<List<MemberMetrics>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activité indisponible. Vérifiez votre connexion puis actualisez.',
                      ),
                      TextButton(
                        onPressed: () => setState(() => _load(org)),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  );
                if (!snap.hasData)
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                final members = snap.data!;
                if (members.isEmpty)
                  return Text(
                    org.isOwner
                        ? 'Ajoutez des commerciaux depuis Équipe & accès.'
                        : 'Aucun commercial rattaché. Contactez votre administrateur.',
                  );
                if (widget.weekly) {
                  final monday = EnterpriseMetricsService.weekStart(
                    DateTime.now(),
                  );
                  final sunday = monday.add(const Duration(days: 6));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Du ${monday.day}/${monday.month} au ${sunday.day}/${sunday.month} • semaine courante',
                      ),
                      const ExpansionTile(
                        title: Text('Comprendre les indicateurs'),
                        children: [
                          Text(
                            'Visites réalisées = étapes avec un compte rendu enregistré. Relances = échéances restantes de la semaine, sans doublon de notification.',
                          )
                        ],
                      ),
                      ...members.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${m.name}${m.active ? '' : ' · Accès révoqué'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _MetricsGrid(
                                values: {
                                  'Visites prévues': '${m.week.planned}',
                                  'Visites réalisées': '${m.week.completed}',
                                  'RDV planifiés': '${m.appointments}',
                                  'Prospects ajoutés': '${m.prospects}',
                                  'Relances à venir': '${m.followUps}',
                                  'Réalisation': m.week.completionRate == null
                                      ? '—'
                                      : '${(m.week.completionRate! * 100).round()} %',
                                },
                              ),
                              ReportingDonut(
                                title: 'Résultats des visites',
                                slices: _statusSlices(m.week.statuses),
                                centerLabel: 'visites',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final active = members.where((m) => m.active).toList();
                int sum(int Function(MemberMetrics) f) =>
                    active.fold(0, (n, m) => n + f(m));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MetricsGrid(
                      values: {
                        if (org.canManageTeam)
                          'Commerciaux': '${active.length}',
                        'Tournées': '${sum((m) => m.today.routes)}',
                        'RDV': '${sum((m) => m.todayAppointments)}',
                        'Rappels': '${sum((m) => m.followUps)}',
                      },
                    ),
                    ReportingChartGrid(charts: [
                      ReportingDonut(
                        title: 'Avancement des visites',
                        centerLabel: 'prévues',
                        slices: [
                          ReportSlice(
                              'Réalisées',
                              sum((m) => m.today.completed),
                              ProspectoColors.green),
                          ReportSlice(
                              'Restantes',
                              sum((m) => m.today.remaining),
                              ProspectoColors.blue),
                        ],
                      ),
                      ReportingDonut(
                        title: 'Résultats des visites',
                        centerLabel: 'visites',
                        slices: _statusSlices({
                          for (final status in active
                              .expand((m) => m.today.statuses.keys)
                              .toSet())
                            status: sum((m) => m.today.statuses[status] ?? 0),
                        }),
                      ),
                    ]),
                    if (!org.canManageTeam && members.isNotEmpty) ...[
                      Text(
                        'Prochaine visite : ${members.first.nextVisit ?? 'Aucune visite restante'}',
                      ),
                      Text(
                        'Prochain RDV : ${members.first.nextAppointment ?? 'Aucun RDV à venir aujourd’hui'}',
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

List<ReportSlice> _statusSlices(Map<String, int> statuses) {
  int count(String key) => statuses.entries
      .where((e) => e.key.trim().toLowerCase() == key)
      .fold(0, (n, e) => n + e.value);
  final present = count('présent') + count('present');
  final absent = count('absent');
  final rdv = count('rdv');
  final other =
      statuses.values.fold(0, (n, v) => n + v) - present - absent - rdv;
  return [
    ReportSlice('Présent', present, ProspectoColors.blue),
    ReportSlice('Absent', absent, const Color(0xFFEF4444)),
    ReportSlice('RDV', rdv, ProspectoColors.green),
    ReportSlice('Autres comptes rendus', other, const Color(0xFF94A3B8)),
  ];
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.values});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.entries
              .map(
                (e) => SizedBox(
                  width: c.maxWidth >= 700
                      ? (c.maxWidth - 24) / 4
                      : c.maxWidth < 240
                          ? c.maxWidth
                          : (c.maxWidth - 8) / 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(e.key, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _OwnerCounts extends StatelessWidget {
  const _OwnerCounts({required this.org});
  final OrgProvider org;
  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('apps')
        .doc(kAppId)
        .collection('orgs')
        .doc(org.orgId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref
          .collection('members')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, members) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref
            .collection('invites')
            .where('active', isEqualTo: true)
            .snapshots(),
        builder: (context, invites) {
          final count = invites.data?.docs
              .where(
                (d) =>
                    d.data()['expiresAt'] is Timestamp &&
                    (d.data()['expiresAt'] as Timestamp).toDate().isAfter(
                          DateTime.now(),
                        ),
              )
              .length;
          return Text(
            '${org.maxSeats ?? '—'} places • ${members.data?.size ?? '—'} membres • ${count ?? '—'} invitations',
          );
        },
      ),
    );
  }
}
