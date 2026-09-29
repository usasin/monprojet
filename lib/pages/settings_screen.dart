// lib/pages/settings_screen.dart
// UI 2026 — Glassmorphism, fond auroré animé, style aligné select_prospects_page

import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../providers/org_provider.dart';
import '../widgets/brand_background.dart';
import '../widgets/workspace_badge.dart';
import 'home_page.dart';
import 'about_screen.dart';
import 'information_screen.dart';
import 'developer_console_screen.dart';
import 'org_members_screen.dart';
import 'org_mode_gate.dart';
import 'team_dashboard_screen.dart';
import '../screens/credits_paywall_page.dart';
import '../services/workspace_preferences.dart';
import '../services/ad_service.dart';
import '../services/developer_access_service.dart';
import '../services/org_service.dart';
import '../config.dart';

import '../theme/prospecto_colors.dart';
// ════════════════════════════════════════════════════════════════
//  Palette 2026
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo     = ProspectoColors.blue;
  static const violet     = ProspectoColors.green;
  static const sky        = ProspectoColors.blueSoft;
  static const mint       = ProspectoColors.green;
  static const coral      = ProspectoColors.peach;
  static const amber      = ProspectoColors.peachSoft;
  static const onLight    = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark     = Color(0xFFF0F2FF);
  static const onDarkSub  = Color(0xFF9099C4);

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeveloper = false;

  @override
  void initState() {
    super.initState();
    _loadDeveloperAccess();
  }

  Future<void> _loadDeveloperAccess() async {
    try {
      final allowed = await DeveloperAccessService()
          .isDeveloper(forceRefresh: true);
      if (mounted) setState(() => _isDeveloper = allowed);
    } catch (_) {
      if (mounted) setState(() => _isDeveloper = false);
    }
  }

  Future<void> _showLanguagePicker() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _LangDialog(prefs: prefs),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps&pcampaignid=web_share',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _shareApp() => Share.share(
    'Découvrez Prospecto – votre outil de prospection terrain :\n'
    'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps',
    subject: 'Prospecto',
  );

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await WorkspacePreferences.clearSessionChoice();
    if (!mounted) return;
    context.read<OrgProvider>().clear();
    Navigator.pushNamedAndRemoveUntil(
      context,
      OrgModeGate.routeName,
      (_) => false,
    );
  }

  void _deleteAccount() {
    final org = context.read<OrgProvider>();
    final ownsEnterprise = org.isOwner ||
        (org.teamAvailable && org.teamRole?.toUpperCase() == 'OWNER');
    if (ownsEnterprise) {
      showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const LText('Transfert requis'),
          content: const LText(
            'Vous êtes l’administrateur principal d’une entreprise. '
            'Transférez d’abord la propriété à un autre membre depuis « Mon entreprise », '
            'puis recommencez la suppression du compte.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const LText('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _P.coral.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_rounded, color: _P.coral, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: LText('Supprimer le compte'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: LText(
          org.teamAvailable
              ? 'Cette action est irréversible. Vous quitterez également votre entreprise. Confirmer ?'.tr()
              : 'Cette action est irréversible. Confirmer ?'.tr(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: LText('Annuler'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await OrgService(kAppId).deleteAccount();
                await FirebaseAuth.instance.signOut();
                await WorkspacePreferences.clearAll();
                if (mounted) {
                  context.read<OrgProvider>().clear();
                  Navigator.pushNamedAndRemoveUntil(
                    context, OrgModeGate.routeName, (_) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: LText(
                        e.toString()
                            .replaceFirst('Bad state: ', '')
                            .replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            child: LText('Supprimer'.tr(), style: const TextStyle(color: _P.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final orgProv   = context.watch<OrgProvider>();
    final isDark    = themeProv.isDark;
    final theme     = themeProv.currentTheme;
    final size      = MediaQuery.of(context).size;
    final maxW      = size.width >= 1024 ? 900.0 : (size.shortestSide >= 600 ? 720.0 : 560.0);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark),
          bottomNavigationBar: _buildBottomBar(isDark, context),
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
                      const SizedBox(height: 8),

                      // ── QR / Partage card
                      _GlassCard(
                        isDark: isDark,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: _P.indigo.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4))],
                              ),
                              child: QrImageView(
                                data: 'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps',
                                version: QrVersions.auto,
                                size: 130,
                                foregroundColor: _P.indigo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LText('Scannez pour installer'.tr(),
                                style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _P.onDarkSub : _P.onLightSub)),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _GradientButton(
                                    label: 'Noter ⭐'.tr(),
                                    icon: Icons.star_rounded,
                                    onTap: _rateApp,
                                    gradient: [_P.amber, _P.coral],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _GradientButton(
                                    label: 'Partager'.tr(),
                                    icon: Icons.share_rounded,
                                    onTap: _shareApp,
                                    gradient: [_P.indigo, _P.violet],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const WorkspaceBadge(),
                      const SizedBox(height: 12),

                      // ── Section Préférences
                      _SectionLabel(label: 'Préférences'.tr(), isDark: isDark),
                      const SizedBox(height: 8),
                      _GlassCard(
                        isDark: isDark,
                        child: Column(
                          children: [
                            // Thème toggle
                            _SettingsTile(
                              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              iconColor: _P.amber,
                              title: isDark ? 'Thème sombre'.tr() : 'Thème clair'.tr(),
                              isDark: isDark,
                              trailing: Switch(
                                value: isDark,
                                onChanged: (_) => themeProv.toggleTheme(),
                                activeColor: _P.indigo,
                              ),
                              onTap: () => themeProv.toggleTheme(),
                            ),
                            _Divider(),
                            _SettingsTile(
                              icon: Icons.language_rounded,
                              iconColor: _P.sky,
                              title: 'Langue'.tr(),
                              isDark: isDark,
                              onTap: _showLanguagePicker,
                            ),
                            _Divider(),
                            if (orgProv.isTeam && orgProv.orgId != null) ...[
                              _SettingsTile(
                                icon: orgProv.canManageTeam
                                    ? Icons.supervisor_account_rounded
                                    : Icons.event_available_rounded,
                                iconColor: _P.indigo,
                                title: orgProv.isOwner
                                    ? 'Direction de l’entreprise'
                                    : orgProv.canManageTeam
                                        ? 'Pilotage commercial'
                                        : 'Mon activité commerciale',
                                subtitle: orgProv.isOwner
                                    ? 'Équipe, accès, calendriers et performance globale'
                                    : orgProv.canManageTeam
                                        ? 'Commerciaux, tournées, rendez-vous et résultats'
                                        : 'Mes tournées, rendez-vous, reportings et autonomie',
                                isDark: isDark,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  TeamDashboardScreen.routeName,
                                ),
                              ),
                              _Divider(),
                              _SettingsTile(
                                icon: Icons.groups_rounded,
                                iconColor: _P.mint,
                                title: orgProv.canManageTeam
                                    ? 'Organisation & membres'.tr()
                                    : 'Mon entreprise'.tr(),
                                subtitle: orgProv.canManageTeam
                                    ? orgProv.orgName
                                    : 'Identité, équipe et accès personnel',
                                isDark: isDark,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  OrgMembersScreen.routeName,
                                ),
                              ),
                              _Divider(),
                            ],
                            if (orgProv.isTeam)
                              _SettingsTile(
                                icon: Icons.workspace_premium_rounded,
                                iconColor: _P.mint,
                                title: 'Forfait entreprise',
                                subtitle: orgProv.plan?.trim().isNotEmpty == true
                                    ? 'Forfait ${orgProv.plan!.toUpperCase()} inclus'
                                    : 'Premium inclus avec votre entreprise',
                                isDark: isDark,
                                onTap: () {
                                  if (orgProv.canManageTeam) {
                                    Navigator.pushNamed(
                                      context,
                                      OrgMembersScreen.routeName,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: LText(
                                          'Le forfait est géré par votre administrateur.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _P.mint.withOpacity(.14),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _P.mint.withOpacity(.28),
                                    ),
                                  ),
                                  child: const LText(
                                    'Actif',
                                    style: TextStyle(
                                      color: _P.mint,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                            else
                              _SettingsTile(
                                icon: Icons.workspace_premium_rounded,
                                iconColor: _P.amber,
                                title: 'Offre Premium'.tr(),
                                subtitle: 'Gérer mon abonnement'.tr(),
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreditsPaywallPage(),
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_P.amber, _P.coral],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const LText(
                                    'Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Section Infos
                      _SectionLabel(label: 'Informations'.tr(), isDark: isDark),
                      const SizedBox(height: 8),
                      _GlassCard(
                        isDark: isDark,
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline_rounded,
                              iconColor: _P.indigo,
                              title: 'À propos de Prospecto'.tr(),
                              isDark: isDark,
                              onTap: () => Navigator.pushNamed(context, AboutScreen.routeName),
                            ),
                            _Divider(),
                            _SettingsTile(
                              icon: Icons.privacy_tip_rounded,
                              iconColor: _P.violet,
                              title: 'Confidentialité & informations'.tr(),
                              isDark: isDark,
                              onTap: () => Navigator.pushNamed(context, InformationScreen.routeName),
                            ),
                            _Divider(),
                            _SettingsTile(
                              icon: Icons.tune_rounded,
                              iconColor: _P.sky,
                              title: 'Choix de confidentialité publicitaire'.tr(),
                              subtitle: 'Modifier mon consentement AdMob'.tr(),
                              isDark: isDark,
                              onTap: () async {
                                await AdService.instance.showPrivacyOptions();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: LText('Options de confidentialité ouvertes lorsqu’elles sont disponibles.'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isDeveloper) ...[
                        _SectionLabel(label: 'Développement', isDark: isDark),
                        const SizedBox(height: 8),
                        _GlassCard(
                          isDark: isDark,
                          child: _SettingsTile(
                            icon: Icons.developer_mode_rounded,
                            iconColor: _P.mint,
                            title: 'Console développeur',
                            subtitle: 'Premium et forfaits entreprise sans paiement',
                            isDark: isDark,
                            onTap: () => Navigator.pushNamed(
                              context,
                              DeveloperConsoleScreen.routeName,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Section Compte
                      _SectionLabel(label: 'Compte'.tr(), isDark: isDark),
                      const SizedBox(height: 8),
                      _GlassCard(
                        isDark: isDark,
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.logout_rounded,
                              iconColor: _P.coral,
                              title: 'Se déconnecter'.tr(),
                              isDark: isDark,
                              onTap: _logout,
                            ),
                            _Divider(),
                            _SettingsTile(
                              icon: Icons.delete_forever_rounded,
                              iconColor: _P.coral,
                              title: 'Supprimer le compte'.tr(),
                              titleColor: _P.coral,
                              isDark: isDark,
                              onTap: _deleteAccount,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Footer
                      Center(
                        child: LText(
                          '© 2026 Digital Solutions AI  •  Confidentialité & RGPD',
                          style: TextStyle(fontSize: 11,
                              color: isDark ? _P.onDarkSub : _P.onLightSub),
                          textAlign: TextAlign.center,
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

  PreferredSizeWidget _buildAppBar(bool isDark) {
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
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LText(
              'Paramètres'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? _P.onDark : _P.onLight,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
    );
  }

  Widget _buildBottomBar(bool isDark, BuildContext ctx) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: _GradientButton(
        label: 'Accueil'.tr(),
        icon: Icons.home_rounded,
        onTap: () => Navigator.pushReplacementNamed(ctx, HomePage.routeName),
        gradient: [_P.indigo, _P.violet],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool isDark;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon, required this.iconColor, required this.title,
    this.subtitle, this.titleColor, required this.isDark, required this.onTap, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(title, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: titleColor ?? (isDark ? _P.onDark : _P.onLight),
                  )),
                  if (subtitle != null)
                    LText(subtitle!, style: TextStyle(
                      fontSize: 12, color: isDark ? _P.onDarkSub : _P.onLightSub,
                    )),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: isDark ? _P.onDarkSub : _P.onLightSub),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.white.withOpacity(0.3), indent: 50, endIndent: 0);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: LText(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2,
          color: isDark ? _P.onDarkSub : _P.onLightSub,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradient;
  const _GradientButton({required this.label, required this.icon, required this.onTap, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: LText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog langue
class _LangDialog extends StatelessWidget {
  final SharedPreferences prefs;
  const _LangDialog({required this.prefs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.language_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LText(
              'Choisir la langue'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Wrap(
        spacing: 16, runSpacing: 12,
        children: [
          _LangOption(code: 'fr', asset: 'assets/images/france.png', label: 'Français', prefs: prefs),
          _LangOption(code: 'en', asset: 'assets/images/united-kingdom.png', label: 'English', prefs: prefs),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String code, asset, label;
  final SharedPreferences prefs;
  const _LangOption({required this.code, required this.asset, required this.label, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await prefs.setString('languageCode', code);
        if (context.mounted) {
          context.setLocale(Locale(code));
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.indigo.withOpacity(0.15)),
          boxShadow: [const BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: 28, height: 20, fit: BoxFit.cover),
            const SizedBox(width: 8),
            LText(label, style: TextStyle(fontWeight: FontWeight.w700, color: _P.onLight)),
          ],
        ),
      ),
    );
  }
}
