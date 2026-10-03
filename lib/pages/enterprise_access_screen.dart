import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../theme/prospecto_colors.dart';
import '../ui/bling.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';
import '../widgets/user_identity_card.dart';
import '../providers/org_provider.dart';
import '../services/account_session_service.dart';
import '../services/developer_access_service.dart';
import 'org_create_screen.dart';
import 'org_join_screen.dart';
import 'login_screen.dart';

class EnterpriseAccessScreen extends StatefulWidget {
  static const routeName = '/enterprise_access';
  const EnterpriseAccessScreen({super.key});

  @override
  State<EnterpriseAccessScreen> createState() => _EnterpriseAccessScreenState();
}

class _EnterpriseAccessScreenState extends State<EnterpriseAccessScreen> {
  bool _isDeveloper = false;
  bool _checkingDeveloper = true;
  bool _creatingDeveloperSpace = false;

  @override
  void initState() {
    super.initState();
    _loadDeveloperAccess();
  }

  Future<void> _loadDeveloperAccess() async {
    var allowed = false;
    try {
      allowed = await DeveloperAccessService().isDeveloper(forceRefresh: true);
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _isDeveloper = allowed;
      _checkingDeveloper = false;
    });
  }

  Future<void> _changeAccount() async {
    await AccountSessionService.signOut(forceAccountPicker: true);
    if (!mounted) return;
    context.read<OrgProvider>().clear();
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginScreen.routeName,
      (_) => false,
    );
  }

  Future<void> _createDeveloperTestSpace() async {
    if (_creatingDeveloperSpace) return;
    setState(() => _creatingDeveloperSpace = true);
    try {
      final activation =
          await DeveloperAccessService().createActivationCode('TEAM');
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        OrgCreateScreen.routeName,
        arguments: {
          'activationCode': activation.code,
          'companyName': 'Entreprise test Prospecto',
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LText(
            'Mode développeur indisponible : $error. Déconnectez-vous puis reconnectez-vous si le droit vient d’être activé.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _creatingDeveloperSpace = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const LText(
            'Espace entreprise',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (FirebaseAuth.instance.currentUser != null) ...[
                      UserIdentityCard(
                        compact: true,
                        isDeveloper: _isDeveloper,
                        onChangeAccount: _changeAccount,
                      ),
                      const SizedBox(height: 16),
                    ],
                    FrostedCard(
                      radius: 28,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const _EnterpriseMark(),
                          const SizedBox(height: 16),
                          LText(
                            'Comment souhaitez-vous commencer ?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 7),
                          LText(
                            'Choisissez l’option qui correspond à votre situation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onSurface.withOpacity(.68),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_checkingDeveloper)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 13),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_isDeveloper) ...[
                      _EnterpriseCard(
                        icon: Icons.developer_mode_rounded,
                        title: _creatingDeveloperSpace
                            ? 'Préparation de l’entreprise test…'
                            : 'Tester Entreprise sans paiement',
                        subtitle:
                            'Mode développeur · crée automatiquement un code Équipe 10 places, sans passer par Stripe.',
                        accent: ProspectoColors.blue,
                        isDark: isDark,
                        onTap: _createDeveloperTestSpace,
                      ),
                      const SizedBox(height: 13),
                    ],
                    _EnterpriseCard(
                      icon: Icons.login,
                      title: 'Déjà membre ? Me connecter',
                      subtitle: 'Retrouvez votre entreprise avec votre compte Google ou votre e-mail, sans code.',
                      isDark: isDark,
                      onTap: () => Navigator.of(context).pushNamed(LoginScreen.routeName),
                    ),
                    const SizedBox(height: 13),
                    _EnterpriseCard(
                      icon: Icons.add_business_rounded,
                      title: 'Créer un espace entreprise',
                      subtitle:
                          'Pour l’administrateur principal disposant d’un code d’activation.',
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .pushNamed(OrgCreateScreen.routeName),
                    ),
                    const SizedBox(height: 13),
                    _EnterpriseCard(
                      icon: Icons.group_add_rounded,
                      title: 'J’ai un code d’invitation',
                      subtitle:
                          'Première activation avec le code nominatif transmis par l’administrateur.',
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .pushNamed(OrgJoinScreen.routeName),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnterpriseMark extends StatelessWidget {
  const _EnterpriseMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ProspectoColors.green, ProspectoColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: ProspectoColors.green.withOpacity(.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 34),
    );
  }
}

class _EnterpriseCard extends StatelessWidget {
  const _EnterpriseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
    this.accent = ProspectoColors.green,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF172033).withOpacity(.82)
                  : Colors.white.withOpacity(.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(.10)
                    : Colors.white.withOpacity(.88),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(isDark ? .08 : .11),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(isDark ? .20 : .13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LText(
                        subtitle,
                        style: TextStyle(
                          color: onSurface.withOpacity(.68),
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
