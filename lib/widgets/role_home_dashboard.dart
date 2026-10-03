import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../pages/all_prospects_finished_page.dart';
import '../pages/follow_up_center_page.dart';
import '../pages/map_page.dart';
import '../pages/org_activity_screen.dart';
import '../pages/reporting_page.dart';
import '../pages/select_prospects_page.dart';
import '../pages/team_dashboard_screen.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../theme/prospecto_colors.dart';
import '../ui/bling.dart';
import 'company_avatar.dart';
import 'localized_text.dart';

/// Accueil métier de l'espace entreprise.
///
/// Chaque rôle dispose d'une hiérarchie d'information différente :
/// - OWNER : direction, accès, capacité et performance globale.
/// - MANAGER : opérations du jour, planning et accompagnement des commerciaux.
/// - REP : journée terrain, prochaine action et reporting.
///
/// Le widget ne remplace aucune fonctionnalité existante : il sert de cockpit
/// et redirige vers les écrans métier déjà en place.
class RoleHomeDashboard extends StatefulWidget {
  const RoleHomeDashboard({
    super.key,
    required this.org,
    required this.isDark,
  });

  final OrgProvider org;
  final bool isDark;

  @override
  State<RoleHomeDashboard> createState() => _RoleHomeDashboardState();
}

class _RoleHomeDashboardState extends State<RoleHomeDashboard> {
  final OrgService _service = OrgService(kAppId);
  Future<_RolePulse>? _pulseFuture;
  String? _pulseKey;

  @override
  void initState() {
    super.initState();
    _ensurePulse();
  }

  @override
  void didUpdateWidget(covariant RoleHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensurePulse();
  }

  void _ensurePulse({bool force = false}) {
    final orgId = widget.org.orgId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final role = widget.org.role?.toUpperCase() ?? 'REP';
    final key = '$orgId|$uid|$role|${DateTime.now().toIso8601String().substring(0, 10)}';
    if (!force && key == _pulseKey && _pulseFuture != null) return;
    _pulseKey = key;
    _pulseFuture = _loadPulse();
  }

  Future<_RolePulse> _loadPulse() async {
    final orgId = widget.org.orgId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (orgId == null || uid == null) return const _RolePulse.empty();

    final memberSnap = await _service.orgRef(orgId).collection('members').get();
    final activeDocs = memberSnap.docs.where((doc) {
      return doc.data()['status']?.toString().toLowerCase() == 'active';
    }).toList();
    final activeReps = activeDocs.where((doc) {
      return doc.data()['role']?.toString().toUpperCase() == 'REP';
    }).toList();
    final managers = activeDocs.where((doc) {
      final role = doc.data()['role']?.toString().toUpperCase();
      return role == 'OWNER' || role == 'MANAGER';
    }).length;

    final role = widget.org.role?.toUpperCase() ?? 'REP';
    final targetReps = role == 'REP'
        ? activeReps.where((doc) => doc.id == uid).toList()
        : activeReps;

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    // Les lectures sont volontairement groupées pour éviter un pic réseau
    // si une entreprise comporte beaucoup de commerciaux.
    final memberPulses = <_MemberPulse>[];
    const batchSize = 8;
    for (var offset = 0; offset < targetReps.length; offset += batchSize) {
      final endOffset = math.min(offset + batchSize, targetReps.length);
      final batch = targetReps.sublist(offset, endOffset);
      memberPulses.addAll(
        await Future.wait(
          batch.map((member) => _loadMemberPulse(orgId, member.id, start, end)),
        ),
      );
    }

    var routes = 0;
    var visits = 0;
    var reported = 0;
    var appointments = 0;
    var rdvWon = 0;
    DateTime? nextAppointment;
    for (final pulse in memberPulses) {
      routes += pulse.routes;
      visits += pulse.visits;
      reported += pulse.reported;
      appointments += pulse.appointments;
      rdvWon += pulse.rdvWon;
      if (pulse.nextAppointment != null &&
          (nextAppointment == null || pulse.nextAppointment!.isBefore(nextAppointment))) {
        nextAppointment = pulse.nextAppointment;
      }
    }

    return _RolePulse(
      activeMembers: activeDocs.length,
      activeReps: activeReps.length,
      managers: managers,
      routes: routes,
      visits: visits,
      reported: reported,
      appointments: appointments,
      rdvWon: rdvWon,
      nextAppointment: nextAppointment,
    );
  }

  Future<_MemberPulse> _loadMemberPulse(
    String orgId,
    String memberUid,
    DateTime start,
    DateTime end,
  ) async {
    final results = await Future.wait([
      _service
          .memberPlans(orgId, memberUid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get(),
      _service
          .memberAppointments(orgId, memberUid)
          .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startsAt', isLessThan: Timestamp.fromDate(end))
          .get(),
    ]);

    final plans = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final appointments = results[1] as QuerySnapshot<Map<String, dynamic>>;

    var visits = 0;
    var reported = 0;
    var rdvWon = 0;
    for (final doc in plans.docs) {
      final data = doc.data();
      visits += List<String>.from(data['prospectIds'] ?? const []).length;
      final reports = Map<String, dynamic>.from(data['reports'] ?? const {});
      reported += reports.length;
      for (final raw in reports.values) {
        if (raw is! Map) continue;
        final report = Map<String, dynamic>.from(raw);
        if ((report['status'] ?? '').toString().toLowerCase() == 'rdv') {
          rdvWon += 1;
        }
      }
    }

    final scheduled = appointments.docs.where((doc) {
      return (doc.data()['status'] ?? 'scheduled').toString().toLowerCase() ==
          'scheduled';
    }).toList();
    DateTime? nextAppointment;
    final now = DateTime.now();
    for (final doc in scheduled) {
      final raw = doc.data()['startsAt'];
      final date = raw is Timestamp ? raw.toDate() : null;
      if (date == null || date.isBefore(now)) continue;
      if (nextAppointment == null || date.isBefore(nextAppointment)) {
        nextAppointment = date;
      }
    }

    return _MemberPulse(
      routes: plans.docs.length,
      visits: visits,
      reported: reported,
      appointments: scheduled.length,
      rdvWon: rdvWon,
      nextAppointment: nextAppointment,
    );
  }

  Future<void> _refresh() async {
    setState(() => _ensurePulse(force: true));
    try {
      final future = _pulseFuture;
      if (future != null) await future;
    } catch (_) {
      // L'état FutureBuilder affiche l'erreur sans bloquer la navigation.
    }
  }

  void _openCockpit(BuildContext context, [int tab = 0]) {
    Navigator.pushNamed(
      context,
      TeamDashboardScreen.routeName,
      arguments: tab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.org.role?.toUpperCase() ?? 'REP';
    final isOwner = role == 'OWNER';
    final isManager = role == 'MANAGER';
    final isRep = !isOwner && !isManager;
    final accent = isOwner
        ? ProspectoColors.blue
        : isManager
            ? ProspectoColors.green
            : ProspectoColors.peach;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoleHero(
          org: widget.org,
          isDark: widget.isDark,
          accent: accent,
          role: role,
        ),
        const SizedBox(height: 14),
        FutureBuilder<_RolePulse>(
          future: _pulseFuture,
          builder: (context, snapshot) {
            final pulse = snapshot.data ?? const _RolePulse.empty();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PulseHeader(
                  title: isRep ? 'Ma journée' : 'Pulse du jour',
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  isDark: widget.isDark,
                  onRefresh: _refresh,
                ),
                const SizedBox(height: 9),
                _MetricsGrid(
                  role: role,
                  pulse: pulse,
                  isDark: widget.isDark,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 9),
                  _InfoStrip(
                    icon: Icons.cloud_off_rounded,
                    color: ProspectoColors.peach,
                    title: 'Indicateurs momentanément indisponibles',
                    subtitle:
                        'Les fonctions Prospecto restent accessibles. Touchez Actualiser pour réessayer.',
                  ),
                ],
                const SizedBox(height: 14),
                _PriorityCard(
                  role: role,
                  pulse: pulse,
                  autonomy: widget.org.canPlanAutonomously,
                  isDark: widget.isDark,
                  onOpen: () {
                    if (isRep) {
                      if (pulse.visits == 0 && widget.org.canPlanAutonomously) {
                        Navigator.pushNamed(context, SelectProspectsPage.routeName);
                      } else if (pulse.visits > pulse.reported) {
                        Navigator.pushNamed(context, MapPage.routeName);
                      } else if (pulse.visits > 0) {
                        Navigator.pushNamed(context, ReportingPage.routeName);
                      } else {
                        _openCockpit(context);
                      }
                    } else if (pulse.activeReps == 0) {
                      _openCockpit(context, 2);
                    } else if (pulse.visits == 0) {
                      _openCockpit(context, 1);
                    } else {
                      _openCockpit(context, 3);
                    }
                  },
                ),
                const SizedBox(height: 18),
                LText(
                  isRep ? 'Mes actions' : 'Centre de pilotage',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : ProspectoColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionGrid(
                  actions: isOwner
                      ? [
                          _RoleAction(
                            icon: Icons.space_dashboard_rounded,
                            title: 'Direction',
                            subtitle: 'Vue globale de l’entreprise',
                            color: ProspectoColors.blue,
                            onTap: () => _openCockpit(context, 0),
                          ),
                          _RoleAction(
                            icon: Icons.calendar_month_rounded,
                            title: 'Planning équipe',
                            subtitle: 'Tournées et rendez-vous',
                            color: ProspectoColors.green,
                            onTap: () => _openCockpit(context, 1),
                          ),
                          _RoleAction(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Équipe & accès',
                            subtitle: 'Rôles, autonomie et membres',
                            color: ProspectoColors.peach,
                            onTap: () => _openCockpit(context, 2),
                          ),
                          _RoleAction(
                            icon: Icons.query_stats_rounded,
                            title: 'Performance',
                            subtitle: 'Résultats et conversion',
                            color: ProspectoColors.green,
                            onTap: () => _openCockpit(context, 3),
                          ),
                        ]
                      : isManager
                          ? [
                              _RoleAction(
                                icon: Icons.today_rounded,
                                title: 'Opérations du jour',
                                subtitle: 'État de l’équipe terrain',
                                color: ProspectoColors.green,
                                onTap: () => _openCockpit(context, 0),
                              ),
                              _RoleAction(
                                icon: Icons.alt_route_rounded,
                                title: 'Planifier',
                                subtitle: 'Attribuer tournées et RDV',
                                color: ProspectoColors.blue,
                                onTap: () => _openCockpit(context, 1),
                              ),
                              _RoleAction(
                                icon: Icons.groups_2_rounded,
                                title: 'Commerciaux',
                                subtitle: 'Autonomie et accompagnement',
                                color: ProspectoColors.peach,
                                onTap: () => _openCockpit(context, 2),
                              ),
                              _RoleAction(
                                icon: Icons.insights_rounded,
                                title: 'Performance',
                                subtitle: 'Suivre l’exécution',
                                color: ProspectoColors.green,
                                onTap: () => _openCockpit(context, 3),
                              ),
                            ]
                          : [
                              if (widget.org.canPlanAutonomously)
                                _RoleAction(
                                  icon: Icons.add_road_rounded,
                                  title: 'Créer une tournée',
                                  subtitle: 'Préparer ma prospection',
                                  color: ProspectoColors.blue,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    SelectProspectsPage.routeName,
                                  ),
                                ),
                              _RoleAction(
                                icon: Icons.play_arrow_rounded,
                                title: 'Démarrer ma tournée',
                                subtitle: 'Carte et prochaines visites',
                                color: ProspectoColors.green,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  MapPage.routeName,
                                ),
                              ),
                              _RoleAction(
                                icon: Icons.fact_check_rounded,
                                title: 'Faire mon reporting',
                                subtitle: 'Qualifier mes visites',
                                color: ProspectoColors.peach,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  ReportingPage.routeName,
                                ),
                              ),
                              _RoleAction(
                                icon: Icons.event_available_rounded,
                                title: 'Mon planning',
                                subtitle: 'Tournées et rendez-vous',
                                color: ProspectoColors.blue,
                                onTap: () => _openCockpit(context),
                              ),
                            ],
                ),
                const SizedBox(height: 18),
                const LText(
                  'Outils',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ProspectoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _CompactTools(
                  showActivity: !isRep,
                  onHistory: () => Navigator.pushNamed(
                    context,
                    AllProspectsFinishedPage.routeName,
                  ),
                  onFollowUp: () => Navigator.pushNamed(
                    context,
                    FollowUpCenterPage.routeName,
                  ),
                  onActivity: () => Navigator.pushNamed(
                    context,
                    OrgActivityScreen.routeName,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({
    required this.org,
    required this.isDark,
    required this.accent,
    required this.role,
  });

  final OrgProvider org;
  final bool isDark;
  final Color accent;
  final String role;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rawName = user?.displayName?.trim();
    final fallback = user?.email?.split('@').first.trim();
    final firstName = (rawName?.isNotEmpty == true ? rawName : fallback) ?? '';
    final roleTitle = role == 'OWNER'
        ? 'Direction'
        : role == 'MANAGER'
            ? 'Management commercial'
            : 'Commercial terrain';
    final mission = role == 'OWNER'
        ? 'Décidez, déléguez et suivez l’activité commerciale sans perdre la vision d’ensemble.'
        : role == 'MANAGER'
            ? 'Organisez le terrain, répartissez l’activité et accompagnez les commerciaux au bon moment.'
            : org.canPlanAutonomously
                ? 'Préparez votre journée, prospectez, reportez et relancez depuis un seul espace.'
                : 'Votre responsable prépare les tournées. Vous vous concentrez sur les visites, le reporting et les relances.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(isDark ? .24 : .16),
            ProspectoColors.blue.withOpacity(isDark ? .16 : .08),
            isDark ? const Color(0xFF101827).withOpacity(.82) : Colors.white.withOpacity(.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accent.withOpacity(isDark ? .35 : .24),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(.11),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompanyAvatar(
                initials: org.initials,
                logoUrl: org.logoUrl,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      org.orgName ?? 'Entreprise',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : ProspectoColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.13),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: LText(
                            roleTitle,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        LText(
                          role,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : ProspectoColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (firstName.isNotEmpty)
            LText(
              'Bonjour $firstName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : ProspectoColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (user?.email?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.account_circle_rounded,
                  size: 15,
                  color: isDark ? Colors.white54 : ProspectoColors.blue,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: LText(
                    user!.email!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : ProspectoColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 3),
          LText(
            role == 'OWNER'
                ? 'Votre entreprise, en un coup d’œil.'
                : role == 'MANAGER'
                    ? 'Votre équipe, prête pour le terrain.'
                    : 'Votre journée commerciale, sans dispersion.',
            style: TextStyle(
              color: isDark ? Colors.white : ProspectoColors.textPrimary,
              fontSize: 23,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          LText(
            mission,
            style: TextStyle(
              color: isDark ? Colors.white70 : ProspectoColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseHeader extends StatelessWidget {
  const _PulseHeader({
    required this.title,
    required this.loading,
    required this.isDark,
    required this.onRefresh,
  });

  final String title;
  final bool loading;
  final bool isDark;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LText(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : ProspectoColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 17),
          label: const LText('Actualiser'),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.role,
    required this.pulse,
    required this.isDark,
    required this.loading,
  });

  final String role;
  final _RolePulse pulse;
  final bool isDark;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rep = role == 'REP';
    final owner = role == 'OWNER';
    final metrics = rep
        ? [
            _Metric(Icons.route_rounded, '${pulse.visits}', 'Visites prévues', ProspectoColors.blue),
            _Metric(Icons.fact_check_rounded, '${pulse.reported}', 'Visites reportées', ProspectoColors.green),
            _Metric(Icons.event_available_rounded, '${pulse.appointments}', 'RDV au planning', ProspectoColors.peach),
            _Metric(Icons.handshake_rounded, '${pulse.rdvWon}', 'RDV obtenus', ProspectoColors.green),
          ]
        : owner
            ? [
                _Metric(Icons.groups_rounded, '${pulse.activeMembers}', 'Membres actifs', ProspectoColors.blue),
                _Metric(Icons.badge_rounded, '${pulse.activeReps}', 'Commerciaux actifs', ProspectoColors.green),
                _Metric(Icons.route_rounded, '${pulse.visits}', 'Visites prévues', ProspectoColors.peach),
                _Metric(Icons.event_available_rounded, '${pulse.appointments}', 'RDV aujourd’hui', ProspectoColors.green),
              ]
            : [
                _Metric(Icons.badge_rounded, '${pulse.activeReps}', 'Commerciaux actifs', ProspectoColors.blue),
                _Metric(Icons.route_rounded, '${pulse.visits}', 'Visites prévues', ProspectoColors.green),
                _Metric(Icons.fact_check_rounded, '${pulse.reported}', 'Visites reportées', ProspectoColors.peach),
                _Metric(Icons.event_available_rounded, '${pulse.appointments}', 'RDV aujourd’hui', ProspectoColors.green),
              ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(132.0, (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(
                    metric: metric,
                    isDark: isDark,
                    loading: loading,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.isDark,
    required this.loading,
  });

  final _Metric metric;
  final bool isDark;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.065) : Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(.10) : ProspectoColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: LText(
                    loading ? '—' : metric.value,
                    key: ValueKey('${metric.label}-${loading ? 'loading' : metric.value}'),
                    style: TextStyle(
                      color: isDark ? Colors.white : ProspectoColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                LText(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : ProspectoColors.textSecondary,
                    fontSize: 10.8,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
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

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.role,
    required this.pulse,
    required this.autonomy,
    required this.isDark,
    required this.onOpen,
  });

  final String role;
  final _RolePulse pulse;
  final bool autonomy;
  final bool isDark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rep = role == 'REP';
    late final String title;
    late final String subtitle;
    late final IconData icon;

    if (rep) {
      if (pulse.visits == 0 && autonomy) {
        title = 'Préparer ma prochaine tournée';
        subtitle = 'Aucune visite n’est prévue aujourd’hui. Créez une tournée quand vous êtes prêt.';
        icon = Icons.add_road_rounded;
      } else if (pulse.visits == 0) {
        title = 'Consulter mon planning';
        subtitle = 'Votre responsable pilote les tournées. Vérifiez les prochaines activités attribuées.';
        icon = Icons.event_note_rounded;
      } else if (pulse.reported < pulse.visits) {
        title = 'Continuer ma journée terrain';
        subtitle = '${pulse.reported}/${pulse.visits} visites sont reportées aujourd’hui.';
        icon = Icons.play_circle_fill_rounded;
      } else {
        title = 'Transformer la journée en suivi';
        subtitle = 'Les visites du jour sont reportées. Préparez maintenant vos relances et prochains rendez-vous.';
        icon = Icons.notifications_active_rounded;
      }
    } else if (pulse.activeReps == 0) {
      title = 'Construire l’équipe commerciale';
      subtitle = 'Ajoutez un premier commercial pour activer le pilotage d’équipe.';
      icon = Icons.person_add_alt_1_rounded;
    } else if (pulse.visits == 0) {
      title = 'Préparer le terrain';
      subtitle = 'Aucune visite n’est planifiée aujourd’hui pour l’équipe. Ouvrez le planning pour répartir l’activité.';
      icon = Icons.calendar_month_rounded;
    } else if (pulse.reported < pulse.visits) {
      title = 'Suivre l’exécution';
      subtitle = '${pulse.reported}/${pulse.visits} visites prévues sont déjà reportées aujourd’hui.';
      icon = Icons.radar_rounded;
    } else {
      title = 'Analyser les résultats';
      subtitle = 'L’activité du jour est reportée. Consultez les résultats et préparez les prochaines actions.';
      icon = Icons.insights_rounded;
    }

    return PressableScale(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ProspectoColors.dark.withOpacity(isDark ? .72 : .94),
              ProspectoColors.blue.withOpacity(.88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: ProspectoColors.blue.withOpacity(.18),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.13),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LText(
                    'PRIORITÉ MAINTENANT',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  LText(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  LText(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});
  final List<_RoleAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map(
                (action) => SizedBox(
                  width: width,
                  child: _ActionCard(action: action),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final _RoleAction action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: action.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 134),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.84),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(.11) : ProspectoColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: action.color.withOpacity(.08),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.color.withOpacity(.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(action.icon, color: action.color, size: 23),
            ),
            const Spacer(),
            LText(
              action.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : ProspectoColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            LText(
              action.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white60 : ProspectoColors.textSecondary,
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTools extends StatelessWidget {
  const _CompactTools({
    required this.showActivity,
    required this.onHistory,
    required this.onFollowUp,
    required this.onActivity,
  });

  final bool showActivity;
  final VoidCallback onHistory;
  final VoidCallback onFollowUp;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _Tool(Icons.history_rounded, 'Historique', onHistory),
      _Tool(Icons.notifications_active_rounded, 'Relances & exports', onFollowUp),
      if (showActivity)
        _Tool(Icons.receipt_long_rounded, 'Journal entreprise', onActivity),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ActionChip(
              avatar: Icon(item.icon, size: 17, color: ProspectoColors.blue),
              label: LText(item.label),
              onPressed: item.onTap,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(.07)
                  : Colors.white.withOpacity(.72),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(.11) : ProspectoColors.border,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                LText(
                  subtitle,
                  style: const TextStyle(
                    color: ProspectoColors.textSecondary,
                    fontSize: 11.5,
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

class _RoleAction {
  const _RoleAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _Metric {
  const _Metric(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _Tool {
  const _Tool(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _RolePulse {
  const _RolePulse({
    required this.activeMembers,
    required this.activeReps,
    required this.managers,
    required this.routes,
    required this.visits,
    required this.reported,
    required this.appointments,
    required this.rdvWon,
    required this.nextAppointment,
  });

  const _RolePulse.empty()
      : activeMembers = 0,
        activeReps = 0,
        managers = 0,
        routes = 0,
        visits = 0,
        reported = 0,
        appointments = 0,
        rdvWon = 0,
        nextAppointment = null;

  final int activeMembers;
  final int activeReps;
  final int managers;
  final int routes;
  final int visits;
  final int reported;
  final int appointments;
  final int rdvWon;
  final DateTime? nextAppointment;
}

class _MemberPulse {
  const _MemberPulse({
    required this.routes,
    required this.visits,
    required this.reported,
    required this.appointments,
    required this.rdvWon,
    required this.nextAppointment,
  });

  final int routes;
  final int visits;
  final int reported;
  final int appointments;
  final int rdvWon;
  final DateTime? nextAppointment;
}
