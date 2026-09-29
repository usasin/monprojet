// lib/pages/home_page.dart
// UI 2026 — Glassmorphism, fond auroré animé, cartes glass premium
// Aligné sur le style de select_prospects_page.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';

import '../providers/theme_provider.dart';
import '../providers/org_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logo_widget.dart';
import 'select_prospects_page.dart';
import 'map_page.dart';
import 'reporting_page.dart';
import 'all_prospects_finished_page.dart';
import 'settings_screen.dart';
import 'team_dashboard_screen.dart';
import 'follow_up_center_page.dart';

import '../widgets/brand_background.dart';
import '../widgets/workspace_badge.dart';
import '../widgets/company_avatar.dart';
import '../widgets/role_home_dashboard.dart';
import '../ui/bling.dart';
import '../services/access_control.dart';

import '../theme/prospecto_colors.dart';
// ════════════════════════════════════════════════════════════════
//  Palette & tokens 2026 (partagée)
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo      = ProspectoColors.blue;
  static const violet      = ProspectoColors.green;
  static const sky         = ProspectoColors.blueSoft;
  static const mint        = ProspectoColors.green;
  static const coral       = ProspectoColors.peach;
  static const amber       = ProspectoColors.peachSoft;
  static const onLight     = ProspectoColors.textPrimary;
  static const onLightSub  = ProspectoColors.textSecondary;
  static const onDark      = Color(0xFFF0F2FF);
  static const onDarkSub   = Color(0xFF9099C4);

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  static const routeName = '/';
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  OrgProvider? _orgProvider;
  bool _messageScheduled = false;

  late final AnimationController _logoCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 5),
  )..repeat();
  late final Animation<double> _logoT = CurvedAnimation(
    parent: _logoCtrl, curve: Curves.easeInOutSine,
  );

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && mounted) {
        final orgProvider = context.read<OrgProvider>();
        _orgProvider = orgProvider;
        orgProvider.addListener(_handleOrgProviderChange);
        try {
          await orgProvider.loadFromUser(uid);
          _handleOrgProviderChange();
        } catch (_) {
          // Les écrans métier afficheront une erreur claire si la connexion
          // empêche réellement l’accès aux données.
        }
      }
    });
  }

  @override
  void dispose() {
    _orgProvider?.removeListener(_handleOrgProviderChange);
    _logoCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _handleOrgProviderChange() {
    if (!mounted || _messageScheduled) return;
    final provider = _orgProvider;
    final message = provider?.accessMessage;
    if (provider == null || message == null || message.isEmpty) return;
    _messageScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LText(message)),
      );
      provider.consumeAccessMessage();
      _messageScheduled = false;
    });
  }

  // ════════ nav items ════════
  List<_NavItem> _navItemsFor(OrgProvider org) {
    final items = <_NavItem>[];
    if (org.isTeam) {
      items.add(
        _NavItem(
          org.isOwner
              ? 'Direction de l’entreprise'
              : org.canManageTeam
                  ? 'Pilotage commercial'
                  : 'Mon activité commerciale',
          org.canManageTeam
              ? Icons.supervisor_account_rounded
              : Icons.event_available_rounded,
          const [ProspectoColors.green, ProspectoColors.blue],
          TeamDashboardScreen.routeName,
        ),
      );
    }
    if (!org.isTeam || org.canPlanAutonomously) {
      items.add(const _NavItem(
        'Planifier',
        Icons.calendar_month_rounded,
        [ProspectoColors.blue, ProspectoColors.green],
        SelectProspectsPage.routeName,
      ));
    }
    items.addAll(const [
      _NavItem('Carte', Icons.map_rounded, [ProspectoColors.blueSoft, ProspectoColors.blue], MapPage.routeName),
      _NavItem('Reporting', Icons.analytics_rounded, [ProspectoColors.green, ProspectoColors.blueSoft], ReportingPage.routeName),
      _NavItem('Historique', Icons.history_rounded, [ProspectoColors.peachSoft, ProspectoColors.peach], AllProspectsFinishedPage.routeName),
      _NavItem('Relances & exports', Icons.notifications_active_rounded, [ProspectoColors.green, ProspectoColors.blue], FollowUpCenterPage.routeName),
      _NavItem('Paramètres', Icons.settings_rounded, [ProspectoColors.green, ProspectoColors.blue], SettingsScreen.routeName),
    ]);
    return items;
  }

  Future<void> _navigate(BuildContext ctx, _NavItem item) async {
    if (item.route == SettingsScreen.routeName) {
      Navigator.pushNamed(ctx, item.route);
      return;
    }
    final ok = await AccessControl.requireLogin(ctx, reason: "Connecte-toi pour accéder à cette section.");
    if (!ok) return;
    if (ctx.mounted) Navigator.pushNamed(ctx, item.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme    = context.watch<ThemeProvider>().currentTheme;
    final isDark   = theme.brightness == Brightness.dark;
    final size     = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final maxW     = size.width >= 1024 ? 900.0 : (isTablet ? 720.0 : 560.0);
    final org = context.watch<OrgProvider>();
    final navItems = _navItemsFor(org);

    // Logo flottant
    final t   = _logoT.value * 2 * math.pi;
    final s   = math.sin(t);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 16,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark, context),
          body: SafeArea(
            top: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      if (org.isTeam) ...[
                        // L'espace entreprise n'est plus une copie du mode solo.
                        // Chaque rôle dispose maintenant de son propre cockpit.
                        RoleHomeDashboard(org: org, isDark: isDark),
                        const SizedBox(height: 22),
                        _NavCard(
                          item: const _NavItem(
                            'Paramètres',
                            Icons.settings_rounded,
                            [ProspectoColors.green, ProspectoColors.blue],
                            SettingsScreen.routeName,
                          ),
                          isDark: isDark,
                          onTap: () => Navigator.pushNamed(
                            context,
                            SettingsScreen.routeName,
                          ),
                        ),
                      ] else ...[
                        // Le mode personnel reste volontairement centré sur
                        // l'action terrain : planifier, prospecter, reporter.
                        AnimatedBuilder(
                          animation: _logoT,
                          builder: (_, __) => Column(
                            children: [
                              Transform.translate(
                                offset: Offset(0, s * 6),
                                child: Transform.rotate(
                                  angle: s * .04,
                                  child: Transform.scale(
                                    scale: 1 + s * .015,
                                    child: const LogoWidget(),
                                  ),
                                ),
                              ),
                              Container(
                                width: 88,
                                height: 10,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.14 - .05 * s.abs()),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassHeroCard(isDark: isDark),
                        const SizedBox(height: 20),
                        ...List.generate(navItems.length, (i) {
                          final item = navItems[i];
                          final delay = i * 80;
                          return AnimatedBuilder(
                            animation: _entranceCtrl,
                            builder: (_, __) {
                              final t = (_entranceCtrl.value - delay / 900).clamp(0.0, 1.0);
                              final curve = Curves.easeOutBack.transform(t);
                              final opacity = curve.clamp(0.0, 1.0);
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - curve)),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _NavCard(
                                      item: item,
                                      isDark: isDark,
                                      onTap: () => _navigate(context, item),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],

                      const SizedBox(height: 8),

                      // ── Footer
                      Center(
                        child: LText(
                          '© 2026 Digital Solutions AI  •  Confidentialité & RGPD',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? _P.onDarkSub : _P.onLightSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, BuildContext ctx) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 8,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.white.withOpacity(isDark ? 0.05 : 0.28)),
        ),
      ),
      title: const WorkspaceBadge(compact: true),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          tooltip: 'Thème'.tr(),
          onPressed: () => ctx.read<ThemeProvider>().toggleTheme(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _NavItem {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  const _NavItem(this.label, this.icon, this.gradient, this.route);
}

// Hero card verre
class _GlassHeroCard extends StatelessWidget {
  final bool isDark;
  const _GlassHeroCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (org.isTeam) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CompanyAvatar(
                      initials: org.initials,
                      logoUrl: org.logoUrl,
                      size: 54,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LText(
                            'ENTREPRISE',
                            style: TextStyle(
                              color: _P.mint,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          LText(
                            org.orgName ?? 'Entreprise',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? _P.onDark : _P.onLight,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (org.slogan?.trim().isNotEmpty == true)
                            LText(
                              org.slogan!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? _P.onDarkSub : _P.onLightSub,
                                fontSize: 11.5,
                              ),
                            ),
                          LText(
                            org.roleLabel,
                            style: const TextStyle(
                              color: _P.mint,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...[
                const WorkspaceBadge(),
                const SizedBox(height: 14),
              ],
              ShaderMask(
                shaderCallback: (r) => _P.primary.createShader(r),
                child: LText(
                  org.roleHomeTitle,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              LText(
                org.roleHomeSubtitle,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: isDark ? _P.onDarkSub : _P.onLightSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // Mini stat chips
              Wrap(
                spacing: 8, runSpacing: 8,
                children: const [
                  _StatChip(emoji: '📍', label: 'Géolocalisation OSM'),
                  _StatChip(emoji: '✨', label: 'Optimisation IA'),
                  _StatChip(emoji: '📊', label: 'Reporting intégré'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stat chip
class _StatChip extends StatelessWidget {
  final String emoji, label;
  const _StatChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _P.indigo.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.indigo.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LText(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          LText(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _P.indigo)),
        ],
      ),
    );
  }
}

// Nav card avec glassmorphism + gradient icône
class _NavCard extends StatelessWidget {
  final _NavItem item;
  final bool isDark;
  final VoidCallback onTap;
  const _NavCard({required this.item, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.80),
              ),
              boxShadow: [
                BoxShadow(color: item.gradient.first.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                // Icône gradient pill
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      bottomLeft: Radius.circular(19),
                    ),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LText(
                    item.label.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: isDark ? _P.onDark : _P.onLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? _P.onDarkSub : _P.onLightSub,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}