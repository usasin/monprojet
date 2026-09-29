import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/prospecto_colors.dart';
import '../ui/bling.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';
import 'org_create_screen.dart';
import 'org_join_screen.dart';

class EnterpriseAccessScreen extends StatelessWidget {
  static const routeName = '/enterprise_access';
  const EnterpriseAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    FrostedCard(
                      radius: 28,
                      surfaceColor: Colors.white.withOpacity(.76),
                      padding: const EdgeInsets.all(22),
                      child: const Column(
                        children: [
                          _EnterpriseMark(),
                          SizedBox(height: 16),
                          LText(
                            'Comment souhaitez-vous commencer ?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: ProspectoColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 7),
                          LText(
                            'Choisissez l’option qui correspond à votre situation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ProspectoColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _EnterpriseCard(
                      icon: Icons.add_business_rounded,
                      title: 'Créer un espace entreprise',
                      subtitle:
                          'Pour un dirigeant ou un responsable commercial disposant d’un code d’activation.',
                      onTap: () => Navigator.of(context)
                          .pushNamed(OrgCreateScreen.routeName),
                    ),
                    const SizedBox(height: 13),
                    _EnterpriseCard(
                      icon: Icons.group_add_rounded,
                      title: 'Rejoindre une entreprise',
                      subtitle:
                          'Pour un salarié ayant reçu un code d’invitation de son responsable.',
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.88)),
              boxShadow: [
                BoxShadow(
                  color: ProspectoColors.green.withOpacity(.11),
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
                    color: ProspectoColors.green.withOpacity(.13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: ProspectoColors.green, size: 28),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: ProspectoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LText(
                        subtitle,
                        style: const TextStyle(
                          color: ProspectoColors.textSecondary,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: ProspectoColors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
