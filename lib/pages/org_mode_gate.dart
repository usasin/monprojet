import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logo_widget.dart';
import '../providers/org_provider.dart';
import '../services/workspace_preferences.dart';
import '../theme/prospecto_colors.dart';
import '../ui/bling.dart';
import '../widgets/brand_background.dart';
import 'enterprise_access_screen.dart';
import 'home_page.dart';
import 'login_screen.dart';
import 'preparing_space_screen.dart';

class OrgModeGate extends StatefulWidget {
  static const routeName = '/org_gate';
  const OrgModeGate({super.key});

  @override
  State<OrgModeGate> createState() => _OrgModeGateState();
}

class _OrgModeGateState extends State<OrgModeGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openPersonal() async {
    await WorkspacePreferences.markOnboardingSeen();
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(forcePersonalWorkspace: true),
        ),
      );
      return;
    }
    await PreparingSpaceScreen.open(
      context,
      action: () => context.read<OrgProvider>().switchToPersonal(user.uid),
      successRoute: HomePage.routeName,
    );
  }

  Future<void> _openEnterprise() async {
    await WorkspacePreferences.markOnboardingSeen();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(EnterpriseAccessScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final wave = math.sin(_controller.value * math.pi * 2);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Transform.translate(
                          offset: Offset(0, wave * 6),
                          child: Transform.rotate(
                            angle: wave * .035,
                            child: const LogoWidget(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const LText(
                          'Bienvenue sur Prospecto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: ProspectoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const LText(
                          'Votre prospection, organisée simplement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ProspectoColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _WorkspaceChoiceCard(
                          badgeLabel: 'Personnel',
                          badgeColor: ProspectoColors.blue,
                          icon: Icons.person_rounded,
                          title: 'Je travaille seul',
                          subtitle: 'Mes prospects et mes tournées personnelles',
                          onTap: _openPersonal,
                        ),
                        const SizedBox(height: 14),
                        _WorkspaceChoiceCard(
                          badgeLabel: 'Entreprise',
                          badgeColor: ProspectoColors.green,
                          icon: Icons.groups_rounded,
                          title: 'J’utilise Prospecto en entreprise',
                          subtitle: 'Créer ou rejoindre une équipe commerciale',
                          onTap: _openEnterprise,
                        ),
                        const SizedBox(height: 19),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          child: const LText(
                            'Déjà un compte ? Se connecter',
                            style: TextStyle(
                              color: ProspectoColors.blue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceChoiceCard extends StatelessWidget {
  const _WorkspaceChoiceCard({
    required this.badgeLabel,
    required this.badgeColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String badgeLabel;
  final Color badgeColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.76),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(.9)),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(.13),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: badgeColor, size: 31),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: badgeColor.withOpacity(.26)),
                        ),
                        child: LText(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LText(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProspectoColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LText(
                        subtitle,
                        style: const TextStyle(
                          color: ProspectoColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: badgeColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
