import '../sales/sales_insights.dart';
import '../widgets/member_history_panel.dart';
import '../models/route_metrics.dart';
import '../widgets/enterprise_overview.dart';

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/prospect.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/company_avatar.dart';
import '../widgets/localized_text.dart';
import 'map_page.dart';
import 'reporting_page.dart';
import 'select_prospects_page.dart';

class TeamDashboardScreen extends StatefulWidget {
  static const routeName = '/team_dashboard';
  const TeamDashboardScreen({
    super.key,
    this.embedded = false,
    this.initialTab = 0,
    this.personal = false,
  });
  final bool embedded, personal;
  final int initialTab;

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  final OrgService _service = OrgService(kAppId);
  String? _selectedMemberUid;
  DateTime _weekStart = _startOfWeek(DateTime.now());
  bool _busy = false;

  static DateTime _startOfWeek(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(
          message
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final orgId = org.orgId;
    if (!org.isTeam || orgId == null) {
      return const Scaffold(
        body: Center(child: LText('Aucun espace entreprise actif.')),
      );
    }

    final role = org.role?.toUpperCase() ?? 'REP';
    final args = ModalRoute.of(context)?.settings.arguments;
    final personal =
        widget.personal || (args is Map && args['personal'] == true);
    final direct = widget.embedded || (args is Map && args['direct'] == true);
    final isManager = org.canManageTeam && !personal;
    final isOwner = role == 'OWNER';
    final pageTitle = personal
        ? 'Ma journée'
        : isOwner
        ? 'Mon entreprise'
        : isManager
        ? 'Mon équipe'
        : 'Ma journée';
    final requestedTab = widget.embedded
        ? widget.initialTab
        : args is Map
        ? args['tab']
        : args;
    final initialTab = isManager && requestedTab is int
        ? requestedTab.clamp(0, 3).toInt()
        : 0;
    return BrandBackground(
      gradientColors: const [
        ProspectoColors.backgroundTop,
        ProspectoColors.blueMist,
        ProspectoColors.peachMist,
      ],
      blurSigma: 15,
      animate: true,
      child: DefaultTabController(
        key: ValueKey('$orgId-$role'),
        length: isManager ? 4 : 1,
        initialIndex: initialTab,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.embedded
              ? null
              : AppBar(
                  title: LText(
                    direct
                        ? const [
                            'Activité du jour',
                            'Planning équipe',
                            'Mes commerciaux',
                            'Performance & reporting',
                          ][initialTab]
                        : pageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  bottom: isManager && !direct
                      ? TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: Colors.transparent,
                          tabs: [
                            _CockpitTab(
                              icon: isOwner
                                  ? Icons.space_dashboard_rounded
                                  : Icons.today_rounded,
                              label: isOwner ? 'Direction' : 'Aujourd’hui',
                            ),
                            const _CockpitTab(
                              icon: Icons.calendar_month_rounded,
                              label: 'Planning',
                            ),
                            _CockpitTab(
                              icon: isOwner
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.groups_2_rounded,
                              label: isOwner ? 'Équipe & accès' : 'Commerciaux',
                            ),
                            const _CockpitTab(
                              icon: Icons.insights_rounded,
                              label: 'Performance',
                            ),
                          ],
                        )
                      : null,
                ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: personal
                ? _service
                      .orgRef(orgId)
                      .collection('members')
                      .where(
                        FieldPath.documentId,
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                      )
                      .snapshots()
                : _service.allMembers(
                    orgId,
                    role: role,
                    uid: FirebaseAuth.instance.currentUser?.uid,
                  ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final members =
                  snapshot.data!.docs
                      .map((doc) => _MemberView(uid: doc.id, data: doc.data()))
                      .toList()
                    ..sort(_memberSort);

              if (!isManager) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                final self = members.where((m) => m.uid == uid).firstOrNull;
                return _CommercialWorkspace(
                  orgId: orgId,
                  member: self,
                  onAddAppointment: uid == null
                      ? null
                      : () => _addAppointment(orgId, uid),
                  service: _service,
                  weekStart: _weekStart,
                  onPreviousWeek: () => setState(
                    () => _weekStart = _weekStart.subtract(
                      const Duration(days: 7),
                    ),
                  ),
                  onNextWeek: () => setState(
                    () => _weekStart = _weekStart.add(const Duration(days: 7)),
                  ),
                );
              }

              final allReps = members.where((m) => m.role == 'REP').toList();
              final activeReps = allReps.where((m) => m.isActive).toList();
              _selectedMemberUid ??= activeReps.isNotEmpty
                  ? activeReps.first.uid
                  : (allReps.isNotEmpty ? allReps.first.uid : null);
              if (_selectedMemberUid != null &&
                  !allReps.any((m) => m.uid == _selectedMemberUid)) {
                _selectedMemberUid = activeReps.isNotEmpty
                    ? activeReps.first.uid
                    : (allReps.isNotEmpty ? allReps.first.uid : null);
              }
              final selectedRep = allReps
                  .where((m) => m.uid == _selectedMemberUid)
                  .firstOrNull;

              final pages = <Widget>[
                _OverviewTab(
                  org: org,
                  members: members,
                  service: _service,
                  onOpenMember: (member) => _openMemberSheet(orgId, member),
                ),
                _ManagerCalendarTab(
                  orgId: orgId,
                  members: allReps,
                  selectedMemberUid: _selectedMemberUid,
                  weekStart: _weekStart,
                  service: _service,
                  onMemberChanged: (value) =>
                      setState(() => _selectedMemberUid = value),
                  onPreviousWeek: () => setState(
                    () => _weekStart = _weekStart.subtract(
                      const Duration(days: 7),
                    ),
                  ),
                  onNextWeek: () => setState(
                    () => _weekStart = _weekStart.add(const Duration(days: 7)),
                  ),
                  onAssignTour: selectedRep?.isActive == true
                      ? () => _assignTour(orgId, _selectedMemberUid!)
                      : null,
                  onAddAppointment: selectedRep?.isActive == true
                      ? () => _addAppointment(orgId, _selectedMemberUid!)
                      : null,
                  onCancelAppointment: (appointmentId) async {
                    final uid = _selectedMemberUid;
                    if (uid == null) return;
                    try {
                      await _service.cancelMemberAppointment(
                        orgId: orgId,
                        memberUid: uid,
                        appointmentId: appointmentId,
                      );
                      _snack('Rendez-vous annulé.');
                    } catch (error) {
                      _snack(error);
                    }
                  },
                ),
                _MembersTab(
                  org: org,
                  orgId: orgId,
                  members: isOwner ? members : allReps,
                  service: _service,
                  busy: _busy,
                  onBusyChanged: (value) {
                    if (mounted) setState(() => _busy = value);
                  },
                  onMessage: _snack,
                  onOpenMember: (member) => _openMemberSheet(orgId, member),
                ),
                _ResultsTab(orgId: orgId, members: allReps, service: _service),
              ];
              return direct ? pages[initialTab] : TabBarView(children: pages);
            },
          ),
        ),
      ),
    );
  }

  static int _memberSort(_MemberView a, _MemberView b) {
    const roleOrder = {'OWNER': 0, 'MANAGER': 1, 'REP': 2};
    final role = (roleOrder[a.role] ?? 9).compareTo(roleOrder[b.role] ?? 9);
    if (role != 0) return role;
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  Future<void> _openMemberSheet(String orgId, _MemberView member) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .55,
        maxChildSize: .96,
        builder: (_, controller) => _MemberDetailSheet(
          orgId: orgId,
          member: member,
          service: _service,
          scrollController: controller,
          onAssignTour: member.isActive && member.role == 'REP'
              ? () {
                  Navigator.pop(sheetContext);
                  _assignTour(orgId, member.uid);
                }
              : null,
          onAddAppointment: member.isActive && member.role == 'REP'
              ? () {
                  Navigator.pop(sheetContext);
                  _addAppointment(orgId, member.uid);
                }
              : null,
          onMessage: _snack,
        ),
      ),
    );
  }

  Future<void> _assignTour(String orgId, String memberUid) async {
    if (_busy) return;
    final result = await showDialog<_TourAssignment>(
      context: context,
      builder: (_) => AssignTourDialog(orgId: orgId),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _service.assignMemberPlan(
        orgId: orgId,
        memberUid: memberUid,
        date: result.date,
        prospectIds: result.prospectIds,
        notes: result.notes,
      );
      _snack('Tournée attribuée au commercial.');
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('existe déjà') && mounted) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const LText('Remplacer la tournée existante ?'),
            content: const LText(
              'Une tournée est déjà enregistrée à cette date. Le remplacement conservera les reportings déjà saisis quand ils concernent les mêmes prospects.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const LText('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LText('Remplacer'),
              ),
            ],
          ),
        );
        if (replace == true) {
          await _service.assignMemberPlan(
            orgId: orgId,
            memberUid: memberUid,
            date: result.date,
            prospectIds: result.prospectIds,
            notes: result.notes,
            replaceExisting: true,
          );
          _snack('Tournée remplacée et attribuée.');
        }
      } else {
        _snack(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAppointment(String orgId, String memberUid) async {
    final result = await showDialog<_AppointmentDraft>(
      context: context,
      builder: (_) => const _AppointmentDialog(),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _saveAppointment(orgId, memberUid, result);
      _snack('Rendez-vous ajouté au calendrier.');
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('conflit') && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const LText('Conflit dans le calendrier'),
            content: const LText(
              'Un autre rendez-vous est déjà prévu sur ce créneau. Voulez-vous quand même ajouter celui-ci ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const LText('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LText('Ajouter quand même'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _saveAppointment(
              orgId,
              memberUid,
              result,
              forceConflict: true,
            );
            _snack('Rendez-vous ajouté malgré le conflit.');
          } catch (retryError) {
            _snack(retryError);
          }
        }
      } else {
        _snack(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAppointment(
    String orgId,
    String memberUid,
    _AppointmentDraft result, {
    bool forceConflict = false,
  }) {
    return _service.upsertMemberAppointment(
      orgId: orgId,
      memberUid: memberUid,
      title: result.title,
      startsAt: result.startsAt,
      durationMinutes: result.durationMinutes,
      address: result.address,
      notes: result.notes,
      forceConflict: forceConflict,
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.org,
    required this.members,
    required this.service,
    required this.onOpenMember,
  });

  final OrgProvider org;
  final List<_MemberView> members;
  final OrgService service;
  final ValueChanged<_MemberView> onOpenMember;

  @override
  Widget build(BuildContext context) {
    final reps = members.where((m) => m.isActive && m.role == 'REP').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        EnterpriseOverview(key: ValueKey('today-${org.orgId}-${org.role}')),
        const SizedBox(height: 18),
        const _SectionTitle('Équipe commerciale'),
        const SizedBox(height: 8),
        if (reps.isEmpty)
          const _EmptyCard(
            icon: Icons.group_add_rounded,
            title: 'Aucun commercial actif',
            subtitle:
                'L’administrateur peut ajouter ou rattacher des commerciaux depuis Équipe & accès.',
          )
        else
          ...reps.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _MemberSummaryCard(
                member: member,
                onTap: () => onOpenMember(member),
              ),
            ),
          ),
      ],
    );
  }
}

class _CockpitTab extends StatelessWidget {
  const _CockpitTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 46,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          LText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ManagerCalendarTab extends StatelessWidget {
  const _ManagerCalendarTab({
    required this.orgId,
    required this.members,
    required this.selectedMemberUid,
    required this.weekStart,
    required this.service,
    required this.onMemberChanged,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onAssignTour,
    required this.onAddAppointment,
    required this.onCancelAppointment,
  });

  final String orgId;
  final List<_MemberView> members;
  final String? selectedMemberUid;
  final DateTime weekStart;
  final OrgService service;
  final ValueChanged<String?> onMemberChanged;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onAssignTour;
  final VoidCallback? onAddAppointment;
  final ValueChanged<String> onCancelAppointment;

  @override
  Widget build(BuildContext context) {
    final selected = members
        .where((m) => m.uid == selectedMemberUid)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMemberUid,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Commercial',
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
                items: members
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.uid,
                        child: Text(
                          m.isActive
                              ? m.displayName
                              : '${m.displayName} · Inactif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onMemberChanged,
              ),
              const SizedBox(height: 12),
              _WeekNavigator(
                weekStart: weekStart,
                onPrevious: onPreviousWeek,
                onNext: onNextWeek,
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusBadge(
                      label: selected.isActive
                          ? 'Accès actif'
                          : 'Accès inactif',
                      color: selected.isActive
                          ? ProspectoColors.green
                          : Colors.grey,
                      icon: selected.isActive
                          ? Icons.verified_user_rounded
                          : Icons.person_off_rounded,
                    ),
                    _StatusBadge(
                      label: selected.routeAutonomy
                          ? 'Autonomie activée'
                          : 'Tournées attribuées uniquement',
                      color: selected.routeAutonomy
                          ? ProspectoColors.green
                          : ProspectoColors.peach,
                      icon: selected.routeAutonomy
                          ? Icons.directions_run_rounded
                          : Icons.lock_clock_rounded,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResponsiveActionPair(
          primary: FilledButton.icon(
            onPressed: onAssignTour,
            icon: const Icon(Icons.alt_route_rounded),
            label: const LText(
              'Attribuer une tournée',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          secondary: OutlinedButton.icon(
            onPressed: onAddAppointment,
            icon: const Icon(Icons.event_available_rounded),
            label: const LText(
              'Ajouter un RDV',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (selectedMemberUid == null)
          const _EmptyCard(
            icon: Icons.people_outline_rounded,
            title: 'Aucun commercial sélectionné',
            subtitle:
                'Votre administrateur doit vous attribuer des commerciaux ; sélectionnez ensuite un commercial.',
          )
        else
          _AgendaPanel(
            orgId: orgId,
            memberUid: selectedMemberUid!,
            memberName: selected?.displayName,
            weekStart: weekStart,
            service: service,
            canCancelAppointments: true,
            onCancelAppointment: onCancelAppointment,
          ),
      ],
    );
  }
}

class _MembersTab extends StatefulWidget {
  const _MembersTab({
    required this.org,
    required this.orgId,
    required this.members,
    required this.service,
    required this.busy,
    required this.onBusyChanged,
    required this.onMessage,
    required this.onOpenMember,
  });

  final OrgProvider org;
  final String orgId;
  final List<_MemberView> members;
  final OrgService service;
  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  final ValueChanged<Object> onMessage;
  final ValueChanged<_MemberView> onOpenMember;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _query = '';
  bool _activeOnly = true;
  @override
  Widget build(BuildContext context) {
    final members = widget.members
        .where(
          (m) =>
              (!_activeOnly || m.isActive) &&
              '${m.displayName} ${m.data['email'] ?? ''}'
                  .toLowerCase()
                  .contains(_query),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher dans mon équipe',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 12),
            Text('${members.length} commerciaux'),
            const Spacer(),
            const Text('Actifs'),
            Switch(
              value: _activeOnly,
              onChanged: (v) => setState(() => _activeOnly = v),
            ),
          ],
        ),
        Expanded(
          child: members.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: LText(
                      'Aucun commercial correspondant. Les rattachements sont gérés par votre administrateur.',
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, i) {
                    final m = members[i];
                    return ListTile(
                      title: Text(m.displayName),
                      subtitle: Text(
                        '${m.data['email'] ?? ''} · ${m.isActive ? 'Actif' : 'Accès révoqué'}',
                      ),
                      leading: const Icon(Icons.person_outline),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenMember(m),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ResultsTab extends StatelessWidget {
  const _ResultsTab({
    required this.orgId,
    required this.members,
    required this.service,
  });

  final String orgId;
  final List<_MemberView> members;
  final OrgService service;

  @override
  Widget build(BuildContext context) {
    return const SalesInsights();
  }

  static Future<List<_MemberStats>> _loadStats(
    String orgId,
    List<_MemberView> members,
    OrgService service,
  ) async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final output = <_MemberStats>[];

    // Les forfaits peuvent compter jusqu'à 25 utilisateurs. On parallélise par
    // petits groupes pour éviter 25 attentes réseau successives sans créer un
    // pic de lectures brutal côté Firestore.
    const batchSize = 6;
    for (var offset = 0; offset < members.length; offset += batchSize) {
      final end = math.min(offset + batchSize, members.length);
      final batch = members.sublist(offset, end);
      output.addAll(
        await Future.wait(
          batch.map(
            (member) => _loadMemberStats(
              orgId: orgId,
              member: member,
              service: service,
              start: start,
            ),
          ),
        ),
      );
    }

    output.sort((a, b) => b.visits.compareTo(a.visits));
    return output;
  }

  static Future<_MemberStats> _loadMemberStats({
    required String orgId,
    required _MemberView member,
    required OrgService service,
    required DateTime start,
  }) async {
    final snap = await service
        .memberPlans(orgId, member.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    var visits = 0;
    var appointments = 0;
    var present = 0;
    var absent = 0;
    var closed = 0;
    var routes = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final ids = List<String>.from(data['prospectIds'] ?? const []);
      if (ids.isNotEmpty) routes += 1;
      final reports = Map<String, dynamic>.from(data['reports'] ?? const {});
      visits += ids
          .toSet()
          .where((id) => RouteMetrics.hasReport(reports[id]))
          .length;
      for (final id in ids.toSet()) {
        final raw = reports[id];
        if (!RouteMetrics.hasReport(raw)) continue;
        final report = Map<String, dynamic>.from(raw as Map);
        final status = (report['status'] ?? '').toString().toLowerCase();
        if (status == 'rdv') appointments += 1;
        if (status == 'présent' || status == 'present') present += 1;
        if (status == 'absent') absent += 1;
        if (report['finishedAt'] != null ||
            status == 'clôturé' ||
            status == 'closed') {
          closed += 1;
        }
      }
    }
    return _MemberStats(
      member: member,
      routes: routes,
      visits: visits,
      appointments: appointments,
      present: present,
      absent: absent,
      closed: closed,
    );
  }
}

class _CommercialWorkspace extends StatelessWidget {
  const _CommercialWorkspace({
    required this.orgId,
    required this.member,
    this.onAddAppointment,
    required this.service,
    required this.weekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final String orgId;
  final _MemberView? member;
  final VoidCallback? onAddAppointment;
  final OrgService service;
  final DateTime weekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    const autonomy = true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const EnterpriseOverview(),
        OutlinedButton.icon(
          onPressed: onAddAppointment,
          icon: const Icon(Icons.add),
          label: const LText('Ajouter un RDV'),
        ),
        const SizedBox(height: 12),
        if (autonomy)
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, SelectProspectsPage.routeName),
            icon: const Icon(Icons.add_road_rounded),
            label: const LText('Créer une tournée'),
          ),
        const SizedBox(height: 12),
        _WeekNavigator(
          weekStart: weekStart,
          onPrevious: onPreviousWeek,
          onNext: onNextWeek,
        ),
        const SizedBox(height: 12),
        if (member == null)
          const _EmptyCard(
            icon: Icons.sync_problem_rounded,
            title: 'Profil entreprise indisponible',
            subtitle:
                'Fermez puis rouvrez l’application pour actualiser votre accès.',
          )
        else
          _AgendaPanel(
            orgId: orgId,
            memberUid: member!.uid,
            weekStart: weekStart,
            service: service,
            canCancelAppointments: false,
          ),
        const SizedBox(height: 12),
        _ResponsiveActionPair(
          primary: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, MapPage.routeName),
            icon: const Icon(Icons.map_rounded),
            label: const LText(
              'Réaliser la tournée',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          secondary: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, ReportingPage.routeName),
            icon: const Icon(Icons.analytics_rounded),
            label: const LText(
              'Faire le reporting',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel({
    required this.orgId,
    required this.memberUid,
    required this.weekStart,
    required this.service,
    required this.canCancelAppointments,
    this.onCancelAppointment,
    this.memberName,
  });

  final String? memberName;
  final String orgId;
  final String memberUid;
  final DateTime weekStart;
  final OrgService service;
  final bool canCancelAppointments;
  final ValueChanged<String>? onCancelAppointment;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AgendaData>(
      future: _loadAgenda(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const _SurfaceCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        final agenda = snapshot.data!;
        if (agenda.plans.isEmpty && agenda.appointments.isEmpty) {
          return const _EmptyCard(
            icon: Icons.event_busy_rounded,
            title: 'Aucune activité cette semaine',
            subtitle: 'Les tournées et rendez-vous attribués apparaîtront ici.',
          );
        }
        return Column(
          children: List.generate(7, (index) {
            final day = weekStart.add(Duration(days: index));
            final dayPlans = agenda.plans
                .where((p) => _sameDay(p.date, day))
                .toList();
            final dayAppointments = agenda.appointments
                .where((a) => _sameDay(a.startsAt, day))
                .toList();
            if (dayPlans.isEmpty && dayAppointments.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      DateFormat(
                        'EEEE d MMMM',
                        Localizations.localeOf(context).languageCode,
                      ).format(day),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (dayPlans.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...dayPlans.map(
                        (plan) => _AgendaLine(
                          icon: Icons.alt_route_rounded,
                          color: ProspectoColors.blue,
                          title: '${plan.prospectIds.length} visite(s)',
                          subtitle: plan.assignedBy.isNotEmpty
                              ? 'Tournée attribuée par ${plan.assignedByName}'
                              : context.read<OrgProvider>().canManageTeam &&
                                    memberUid !=
                                        FirebaseAuth.instance.currentUser?.uid
                              ? 'Tournée de ${memberName ?? 'commercial'}'
                              : 'Ma tournée',
                        ),
                      ),
                    ],
                    if (dayAppointments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...dayAppointments.map(
                        (appointment) => _AgendaLine(
                          icon: Icons.event_available_rounded,
                          color: ProspectoColors.green,
                          title:
                              '${DateFormat('HH:mm').format(appointment.startsAt)} · ${appointment.title}',
                          subtitle: appointment.address.isNotEmpty
                              ? appointment.address
                              : '${appointment.durationMinutes} min',
                          trailing: canCancelAppointments
                              ? IconButton(
                                  tooltip: 'Annuler le rendez-vous'.tr(),
                                  onPressed: () =>
                                      onCancelAppointment?.call(appointment.id),
                                  icon: const Icon(Icons.cancel_outlined),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Future<_AgendaData> _loadAgenda() async {
    final end = weekStart.add(const Duration(days: 7));
    final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      service
          .memberPlans(orgId, memberUid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get(),
      service
          .memberAppointments(orgId, memberUid)
          .where(
            'startsAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('startsAt', isLessThan: Timestamp.fromDate(end))
          .get(),
    ]);
    final planSnap = snapshots[0];
    final appointmentSnap = snapshots[1];
    final plans = planSnap.docs.map(_PlanView.fromDoc).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final appointments =
        appointmentSnap.docs
            .map(_AppointmentView.fromDoc)
            .where((item) => item.status == 'scheduled')
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _AgendaData(plans: plans, appointments: appointments);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MemberDetailSheet extends StatelessWidget {
  const _MemberDetailSheet({
    required this.orgId,
    required this.member,
    required this.service,
    required this.scrollController,
    required this.onMessage,
    this.onAssignTour,
    this.onAddAppointment,
  });

  final String orgId;
  final _MemberView member;
  final OrgService service;
  final ScrollController scrollController;
  final ValueChanged<Object> onMessage;
  final VoidCallback? onAssignTour;
  final VoidCallback? onAddAppointment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: ProspectoColors.green.withOpacity(.14),
              foregroundColor: ProspectoColors.green,
              child: Icon(_roleIcon(member.role), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    member.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  LText(
                    _roleLabel(member.role),
                    style: const TextStyle(
                      color: ProspectoColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(
              label: member.isActive ? 'Accès actif' : 'Accès inactif',
              color: member.isActive ? ProspectoColors.green : Colors.grey,
              icon: member.isActive
                  ? Icons.verified_user_rounded
                  : Icons.person_off_rounded,
            ),
            if (member.role == 'REP')
              _StatusBadge(
                label: member.routeAutonomy
                    ? 'Autonomie activée'
                    : 'Tournées attribuées uniquement',
                color: member.routeAutonomy
                    ? ProspectoColors.blue
                    : ProspectoColors.peach,
                icon: member.routeAutonomy
                    ? Icons.route_rounded
                    : Icons.lock_clock_rounded,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (onAssignTour != null || onAddAppointment != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onAssignTour != null)
                FilledButton.icon(
                  onPressed: onAssignTour,
                  icon: const Icon(Icons.alt_route_rounded),
                  label: const LText('Attribuer une tournée'),
                ),
              if (onAddAppointment != null)
                OutlinedButton.icon(
                  onPressed: onAddAppointment,
                  icon: const Icon(Icons.event_available_rounded),
                  label: const LText('Ajouter un RDV'),
                ),
            ],
          ),
        const SizedBox(height: 14),
        FutureBuilder<List<_MemberStats>>(
          future: _ResultsTab._loadStats(orgId, [member], service),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const _SurfaceCard(
                child: LText('Chargement des résultats des 30 derniers jours…'),
              );
            }
            return _StatsCard(stats: snapshot.data!.first);
          },
        ),
        const SizedBox(height: 14),
        MemberHistoryPanel(orgId: orgId, memberUid: member.uid),
        const SizedBox(height: 14),
        const _SectionTitle('Prochaines activités'),
        const SizedBox(height: 8),
        _AgendaPanel(
          orgId: orgId,
          memberUid: member.uid,
          memberName: member.displayName,
          weekStart: _TeamDashboardScreenState._startOfWeek(DateTime.now()),
          service: service,
          canCancelAppointments: false,
        ),
      ],
    );
  }
}

class AssignTourDialog extends StatefulWidget {
  const AssignTourDialog({super.key, required this.orgId, this.firestore});
  final String orgId;
  final FirebaseFirestore? firestore;

  @override
  State<AssignTourDialog> createState() => AssignTourDialogState();
}

class AssignTourDialogState extends State<AssignTourDialog> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  final _notes = TextEditingController();
  final _search = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgRef = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('apps')
        .doc(kAppId)
        .collection('orgs')
        .doc(widget.orgId);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      title: const LText('Attribuer une tournée'),
      content: SizedBox(
        width: math.min(MediaQuery.of(context).size.width * .88, 520.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: const LText('Date de la tournée'),
              subtitle: LText(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null && mounted) setState(() => _date = date);
              },
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Rechercher un prospect',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: orgRef
                    .collection('prospects')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: LText('Chargement des prospects impossible.'),
                    );
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final query = _search.text.trim().toLowerCase();
                  final prospects = snapshot.data!.docs
                      .map((doc) => Prospect.fromFirestore(doc.data(), doc.id))
                      .where(
                        (p) =>
                            query.isEmpty ||
                            p.name.toLowerCase().contains(query) ||
                            p.address.toLowerCase().contains(query),
                      )
                      .toList();
                  if (prospects.isEmpty) {
                    return const Center(
                      child: LText('Aucun prospect disponible.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: prospects.length,
                    itemBuilder: (context, index) {
                      final prospect = prospects[index];
                      final checked = _selected.contains(prospect.id);
                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: LText(
                          prospect.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: LText(
                          prospect.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(prospect.id);
                          } else {
                            _selected.remove(prospect.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Consignes (facultatif)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _TourAssignment(
                    date: _date,
                    prospectIds: _selected.toList(),
                    notes: _notes.text.trim(),
                  ),
                ),
          icon: const Icon(Icons.send_rounded),
          label: LText('Attribuer (${_selected.length})'),
        ),
      ],
    );
  }
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog();

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 2));
  int _duration = 60;

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const LText('Ajouter un rendez-vous'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: math.min(MediaQuery.of(context).size.width * .88, 480.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Objet du rendez-vous',
                  prefixIcon: Icon(Icons.event_note_rounded),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const LText('Date et heure'),
                subtitle: LText(
                  DateFormat('dd/MM/yyyy HH:mm').format(_startsAt),
                ),
                onTap: _pickDateTime,
              ),
              DropdownButtonFormField<int>(
                value: _duration,
                decoration: const InputDecoration(
                  labelText: 'Durée',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [30, 45, 60, 90, 120]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes min'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _duration = value ?? 60),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse (facultatif)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Consignes (facultatif)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Annuler'),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _AppointmentDraft(
                    title: _title.text.trim(),
                    startsAt: _startsAt,
                    durationMinutes: _duration,
                    address: _address.text.trim(),
                    notes: _notes.text.trim(),
                  ),
                ),
          child: const LText('Ajouter'),
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }
}

class _CompanyRoleHeader extends StatelessWidget {
  const _CompanyRoleHeader({required this.org});
  final OrgProvider org;

  @override
  Widget build(BuildContext context) {
    final manager = org.role?.toUpperCase() == 'MANAGER';
    return _SurfaceCard(
      child: Row(
        children: [
          CompanyAvatar(initials: org.initials, logoUrl: org.logoUrl, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  org.orgName ?? 'Entreprise',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                LText(
                  manager
                      ? 'Responsable commercial · pilotage opérationnel'
                      : 'Administrateur principal · accès complet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProspectoColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final _MemberStats stats;

  @override
  Widget build(BuildContext context) {
    final rate = stats.visits == 0
        ? 0
        : ((stats.appointments / stats.visits) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              stats.member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniMetric(label: 'Tournées', value: '${stats.routes}'),
                _MiniMetric(label: 'Visites', value: '${stats.visits}'),
                _MiniMetric(label: 'RDV', value: '${stats.appointments}'),
                _MiniMetric(label: 'Clôturés', value: '${stats.closed}'),
                _MiniMetric(label: 'Taux RDV', value: '$rate %'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSummaryCard extends StatelessWidget {
  const _MemberSummaryCard({required this.member, required this.onTap});
  final _MemberView member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: ProspectoColors.green.withOpacity(.14),
          foregroundColor: ProspectoColors.green,
          child: const Icon(Icons.person_rounded),
        ),
        title: LText(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: LText(
          member.routeAutonomy
              ? 'Autonomie activée'
              : 'Tournées attribuées uniquement',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ProspectoColors.blue),
            const SizedBox(height: 8),
            LText(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            LText(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ProspectoColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ProspectoColors.blue.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LText(
        '$label : $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: LText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    return _SurfaceCard(
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: LText(
              '${DateFormat('dd/MM').format(weekStart)} → ${DateFormat('dd/MM/yyyy').format(end)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _AgendaLine extends StatelessWidget {
  const _AgendaLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                LText(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ProspectoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ResponsiveActionPair extends StatelessWidget {
  const _ResponsiveActionPair({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 8), secondary],
          );
        }
        return Row(
          children: [
            Expanded(child: primary),
            const SizedBox(width: 8),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(.08)
            : Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(dark ? .12 : .85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          Icon(icon, size: 40, color: ProspectoColors.blue),
          const SizedBox(height: 8),
          LText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          LText(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProspectoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return LText(
      label,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _PeriodNotice extends StatelessWidget {
  const _PeriodNotice();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, color: ProspectoColors.blue),
          SizedBox(width: 10),
          Expanded(
            child: LText(
              'Statistiques calculées sur les 30 derniers jours à partir des reportings enregistrés.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LText(
          'Chargement impossible : $message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MemberView {
  const _MemberView({required this.uid, required this.data});
  final String uid;
  final Map<String, dynamic> data;

  String get role => (data['role'] ?? 'REP').toString().toUpperCase();
  String get status => (data['status'] ?? 'active').toString().toLowerCase();
  bool get isActive => status == 'active';
  bool get routeAutonomy => true;
  String get displayName {
    final fullName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
        .trim();
    final name = fullName.isNotEmpty
        ? fullName
        : (data['displayName'] ?? data['name'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    return name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Membre');
  }
}

class _PlanView {
  const _PlanView({
    required this.date,
    required this.prospectIds,
    required this.assignedBy,
    required this.assignedByName,
  });
  final DateTime date;
  final List<String> prospectIds;
  final String assignedBy;
  final String assignedByName;

  factory _PlanView.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(doc.id) ?? DateTime.now();
    return _PlanView(
      date: date,
      prospectIds: List<String>.from(data['prospectIds'] ?? const []),
      assignedBy: (data['assignedBy'] ?? '').toString(),
      assignedByName: (data['assignedByName'] ?? 'Responsable').toString(),
    );
  }
}

class _AppointmentView {
  const _AppointmentView({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    required this.address,
    required this.status,
  });
  final String id;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final String address;
  final String status;

  factory _AppointmentView.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawDate = data['startsAt'];
    return _AppointmentView(
      id: doc.id,
      title: (data['title'] ?? 'Rendez-vous').toString(),
      startsAt: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      address: (data['address'] ?? '').toString(),
      status: (data['status'] ?? 'scheduled').toString(),
    );
  }
}

class _AgendaData {
  const _AgendaData({required this.plans, required this.appointments});
  final List<_PlanView> plans;
  final List<_AppointmentView> appointments;
}

class _MemberStats {
  const _MemberStats({
    required this.member,
    required this.routes,
    required this.visits,
    required this.appointments,
    required this.present,
    required this.absent,
    required this.closed,
  });
  final _MemberView member;
  final int routes;
  final int visits;
  final int appointments;
  final int present;
  final int absent;
  final int closed;
}

class _TourAssignment {
  const _TourAssignment({
    required this.date,
    required this.prospectIds,
    required this.notes,
  });
  final DateTime date;
  final List<String> prospectIds;
  final String notes;
}

class _AppointmentDraft {
  const _AppointmentDraft({
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    required this.address,
    required this.notes,
  });
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final String address;
  final String notes;
}

String _roleLabel(String role) {
  switch (role.toUpperCase()) {
    case 'OWNER':
      return 'Administrateur principal';
    case 'MANAGER':
      return 'Responsable commercial';
    default:
      return 'Commercial';
  }
}

IconData _roleIcon(String role) {
  switch (role.toUpperCase()) {
    case 'OWNER':
      return Icons.workspace_premium_rounded;
    case 'MANAGER':
      return Icons.supervisor_account_rounded;
    default:
      return Icons.person_rounded;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
