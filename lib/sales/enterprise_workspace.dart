import 'solo_tours.dart';
import '../widgets/brand_background.dart';
import '../theme/prospecto_colors.dart';
import '../pages/all_prospects_finished_page.dart';
import 'sales_tour_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/org_provider.dart';
import '../providers/theme_provider.dart';
import '../pages/org_members_screen.dart';
import '../pages/team_dashboard_screen.dart';
import '../pages/settings_screen.dart';
import '../pages/select_prospects_page.dart';
import '../pages/follow_up_center_page.dart';
import '../pages/reporting_page.dart';
import '../widgets/workspace_badge.dart';
import '../widgets/enterprise_overview.dart';
import 'sales_insights.dart';
import 'sales_portfolio.dart';
import 'enterprise_home.dart';
import 'enterprise_repository.dart';
import 'enterprise_portfolio.dart';
import 'enterprise_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Role-specific navigation. Administrative roles never inherit Solo shortcuts.
class EnterpriseWorkspace extends StatefulWidget {
  const EnterpriseWorkspace({super.key});
  @override
  State<EnterpriseWorkspace> createState() => _EnterpriseWorkspaceState();
}

class _EnterpriseWorkspaceState extends State<EnterpriseWorkspace> {
  int _index = 0;
  EnterpriseController? _enterprise;
  String? _enterpriseOrg;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final org = context.watch<OrgProvider>();
    final ownerOrg = org.canManageTeam
        ? '${org.orgId}:${org.role}:${FirebaseAuth.instance.currentUser?.uid}'
        : null;
    if (ownerOrg != _enterpriseOrg) {
      _enterprise?.dispose();
      _enterpriseOrg = ownerOrg;
      _enterprise = ownerOrg == null
          ? null
          : EnterpriseController(EnterpriseRepository(org.orgId!));
      _index = 0;
      _enterprise?.refresh();
    }
  }

  @override
  void dispose() {
    _enterprise?.dispose();
    super.dispose();
  }

  void _navigate(int index) {
    setState(() => _index = index);
    // Reflect team changes and field results when returning to the overview.
    if (index == 0) _enterprise?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final manager = org.isTeam && org.canManageTeam;
    final owner = org.isTeam && org.isOwner;
    final labels = owner
        ? ['Entreprise', 'Prospects', 'Équipes', 'Planning', 'Résultats']
        : manager
            ? [
                'Mon équipe',
                'Prospects',
                'Commerciaux',
                'Planning',
                'Résultats'
              ]
            : ['Aujourd’hui', 'Prospects', 'Tournées', 'Résultats'];
    final icons = owner
        ? [
            Icons.dashboard_outlined,
            Icons.people_outline,
            Icons.groups_outlined,
            Icons.calendar_month_outlined,
            Icons.insights_outlined,
          ]
        : manager
            ? [
                Icons.dashboard_outlined,
                Icons.people_outline,
                Icons.groups_outlined,
                Icons.calendar_month_outlined,
                Icons.insights_outlined,
              ]
            : [
                Icons.today_outlined,
                Icons.business_outlined,
                Icons.route_outlined,
                Icons.insights_outlined,
              ];
    Widget page;
    if (owner && _enterprise != null) {
      page = switch (_index) {
        0 => EnterpriseHome(controller: _enterprise!),
        1 => EnterprisePortfolio(controller: _enterprise!, embedded: true),
        2 => const OrgMembersScreen(embedded: true),
        3 => const TeamDashboardScreen(embedded: true, initialTab: 1),
        _ => const SalesInsights(),
      };
    } else if (manager && _enterprise != null) {
      page = switch (_index) {
        0 => EnterpriseHome(controller: _enterprise!),
        1 => EnterprisePortfolio(controller: _enterprise!, embedded: true),
        2 => const TeamDashboardScreen(embedded: true, initialTab: 2),
        3 => const TeamDashboardScreen(embedded: true, initialTab: 1),
        _ => const SalesInsights(),
      };
    } else if (_index == 0) {
      page = _DailyHub(onPlanning: () => setState(() => _index = 2));
    } else if (_index == 1) {
      page = owner
          ? const OrgMembersScreen(embedded: true)
          : manager
              ? const TeamDashboardScreen(embedded: true, initialTab: 2)
              : SalesPortfolio(orgId: (org.isTeam ? org.orgId! : ''));
    } else if (_index == 2) {
      page = manager
          ? const TeamDashboardScreen(embedded: true, initialTab: 1)
          : const _ToursHub();
    } else {
      page = const SalesInsights();
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        cardTheme: theme.cardTheme.copyWith(
          color: (dark ? const Color(0xFF203344) : Colors.white).withValues(
            alpha: .78,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: ProspectoColors.blue.withValues(alpha: .15),
            ),
          ),
        ),
      ),
      child: BrandBackground(
        animate: false,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const WorkspaceBadge(compact: true),
            titleSpacing: 8,
            actions: [
              IconButton(
                tooltip: 'Paramètres',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () async {
                  if (!owner || _enterprise == null) {
                    await Navigator.pushNamed(
                      context,
                      SettingsScreen.routeName,
                    );
                    return;
                  }
                  final choice = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.tune),
                            title: const Text('Indicateurs de l’entreprise'),
                            onTap: () => Navigator.pop(ctx, 'display'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings_outlined),
                            title: const Text('Paramètres de l’application'),
                            onTap: () => Navigator.pop(ctx, 'app'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  if (choice == 'display') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => EnterpriseSettingsPage(
                          orgId: org.orgId!,
                          settings: org.displaySettings,
                        ),
                      ),
                    );
                    await _enterprise?.refresh();
                  } else if (choice == 'app') {
                    await Navigator.pushNamed(
                      context,
                      SettingsScreen.routeName,
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'Changer le thème',
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (wide) ...[
                  NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _index,
                    onDestinationSelected: _navigate,
                    labelType: NavigationRailLabelType.all,
                    destinations: List.generate(
                      labels.length,
                      (i) => NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('${org.orgId}:${org.role}:$_index'),
                    child: page,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : EnterpriseBottomBar(
                  labels: labels,
                  icons: icons,
                  selectedIndex: _index,
                  onSelected: _navigate,
                ),
        ),
      ),
    );
  }
}

class _DailyHub extends StatelessWidget {
  const _DailyHub({required this.onPlanning});
  final VoidCallback onPlanning;
  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          org.isTeam && org.isOwner
              ? 'Entreprise'
              : org.isTeam && org.canManageTeam
                  ? 'Mon équipe'
                  : 'Ma journée',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (org.isTeam) const EnterpriseOverview() else const SoloToday(),
        if (!org.isTeam || !org.canManageTeam)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPlanning,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Voir ma tournée'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    FollowUpCenterPage.routeName,
                  ),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Rappels de visite'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, ReportingPage.routeName),
                  icon: const Icon(Icons.pie_chart_outline),
                  label: const Text('Reporting'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const SalesInsights(summary: true),
      ],
    );
  }
}

class _ToursHub extends StatelessWidget {
  const _ToursHub();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tournées & rendez-vous',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Historique des visites',
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AllProspectsFinishedPage.routeName,
                  ),
                ),
                IconButton(
                  tooltip: 'Organiser une tournée',
                  onPressed: () => Navigator.pushNamed(
                      context, SelectProspectsPage.routeName),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SalesTourSuggestion(
                      orgId: context.read<OrgProvider>().isTeam
                          ? context.read<OrgProvider>().orgId!
                          : '',
                    ),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Visites prioritaires'),
              ),
            ),
          ),
          Expanded(
            child: context.watch<OrgProvider>().isTeam
                ? const TeamDashboardScreen(embedded: true, personal: true)
                : const SoloTours(),
          ),
        ],
      );
}

class EnterpriseBottomBar extends StatelessWidget {
  const EnterpriseBottomBar(
      {super.key,
      required this.labels,
      required this.icons,
      required this.selectedIndex,
      required this.onSelected});
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
        child: SafeArea(
            top: false,
            child: SizedBox(
                height: 76,
                child: Row(children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                        child: Semantics(
                            button: true,
                            selected: selectedIndex == i,
                            label: labels[i],
                            child: Tooltip(
                                message: labels[i],
                                child: InkWell(
                                  onTap: () => onSelected(i),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 8),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                width: 54,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                    color: selectedIndex == i
                                                        ? ProspectoColors.blue
                                                            .withValues(
                                                                alpha: .18)
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                child: Icon(icons[i],
                                                    size: 24,
                                                    color: selectedIndex == i
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: .7))),
                                            const SizedBox(height: 5),
                                            SizedBox(
                                                height: 18,
                                                child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(labels[i],
                                                        maxLines: 1,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                selectedIndex ==
                                                                        i
                                                                    ? FontWeight
                                                                        .w800
                                                                    : FontWeight
                                                                        .w600)))),
                                          ])),
                                )))),
                ]))),
      );
}
