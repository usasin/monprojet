import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';
import '../widgets/localized_text.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';
  const AboutScreen({super.key});

  static final Uri _website =
      Uri.parse('https://digitalsolutionsai.com/applications/prospecto/');
  static final Uri _contact = Uri(
    scheme: 'mailto',
    path: 'contact@digitalsolutionsai.com',
    queryParameters: {'subject': 'Prospecto — demande d’information'},
  );

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs = theme.colorScheme;

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [
          ProspectoColors.backgroundTop,
          ProspectoColors.blueMist,
          ProspectoColors.peachMist,
        ],
        blurSigma: 12,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const LText(
              'À propos de Prospecto',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FrostedCard(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: ProspectoColors.blue.withOpacity(.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: ProspectoColors.blue.withOpacity(.20),
                                ),
                              ),
                              child: const LText(
                                'PROSPECTION TERRAIN',
                                style: TextStyle(
                                  color: ProspectoColors.blue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const LogoWidget(),
                            const SizedBox(height: 18),
                            LText(
                              'Prospecto',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LText(
                              'Transformez une journée de prospection en parcours organisé et exploitable.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ProspectoColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LText(
                              'Prospecto centralise la recherche de prospects, la préparation des tournées commerciales, les visites terrain, les relances et le reporting pour garder le commercial concentré sur l’essentiel : rencontrer, suivre et développer ses clients.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface.withOpacity(.82),
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Tout le cycle de prospection, au même endroit',
                              subtitle:
                                  'De la préparation du secteur jusqu’au compte rendu après visite.',
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _FeaturePill(
                                  icon: Icons.travel_explore_rounded,
                                  label: 'Recherche de prospects',
                                ),
                                _FeaturePill(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'Planification des visites',
                                ),
                                _FeaturePill(
                                  icon: Icons.route_rounded,
                                  label: 'Tournées intelligentes',
                                ),
                                _FeaturePill(
                                  icon: Icons.map_rounded,
                                  label: 'Carte & itinéraire',
                                ),
                                _FeaturePill(
                                  icon: Icons.fact_check_rounded,
                                  label: 'Compte rendu terrain',
                                ),
                                _FeaturePill(
                                  icon: Icons.notifications_active_rounded,
                                  label: 'Relances & historique',
                                ),
                                _FeaturePill(
                                  icon: Icons.analytics_rounded,
                                  label: 'Reporting commercial',
                                ),
                                _FeaturePill(
                                  icon: Icons.groups_rounded,
                                  label: 'Pilotage d’équipe',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 700;
                          final cards = [
                            const _ValueCard(
                              icon: Icons.event_available_rounded,
                              title: 'Préparer',
                              body:
                                  'Organisez vos journées, sélectionnez vos prospects et préparez vos visites avant de prendre la route.',
                            ),
                            const _ValueCard(
                              icon: Icons.location_on_rounded,
                              title: 'Prospecter',
                              body:
                                  'Retrouvez vos étapes, ouvrez l’itinéraire et gardez les informations utiles accessibles sur le terrain.',
                            ),
                            const _ValueCard(
                              icon: Icons.insights_rounded,
                              title: 'Piloter',
                              body:
                                  'Transformez chaque visite en prochaine action grâce aux statuts, relances, historiques et reportings.',
                            ),
                          ];
                          if (stacked) {
                            return Column(
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  cards[i],
                                  if (i != cards.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i != cards.length - 1)
                                  const SizedBox(width: 12),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.business_center_rounded,
                              title: 'Solo ou en équipe commerciale',
                              subtitle:
                                  'Prospecto s’adapte au niveau d’organisation dont vous avez besoin.',
                            ),
                            const SizedBox(height: 16),
                            const _ModeRow(
                              icon: Icons.person_rounded,
                              title: 'Mode Solo',
                              body:
                                  'Pour organiser ses propres prospects, tournées, visites, relances et historiques.',
                            ),
                            const Divider(height: 28),
                            const _ModeRow(
                              icon: Icons.groups_2_rounded,
                              title: 'Mode Entreprise',
                              body:
                                  'Pour partager les prospects, gérer les rôles, attribuer des tournées et suivre l’activité commerciale.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.apartment_rounded,
                              title: 'Une application Digital Solutions AI',
                              subtitle: 'Smart tools. Human impact.',
                            ),
                            const SizedBox(height: 12),
                            LText(
                              'Digital Solutions AI conçoit des applications métiers, automatisations et outils IA pensés pour réduire les tâches répétitives et redonner du temps aux équipes pour leur travail réel.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withOpacity(.82),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _open(_website),
                                  icon: const Icon(Icons.language_rounded),
                                  label: const LText('Site officiel'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _open(_contact),
                                  icon: const Icon(Icons.mail_outline_rounded),
                                  label: const LText('Nous contacter'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      LText(
                        'Prospecto • Version 1.3.11 (41)',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ProspectoColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LText(
                        '© 2026 Digital Solutions AI. Tous droits réservés.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ProspectoColors.textSecondary,
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ProspectoColors.blue.withOpacity(.11),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: ProspectoColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              LText(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ProspectoColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProspectoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ProspectoColors.green),
          const SizedBox(width: 7),
          LText(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FrostedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ProspectoColors.green, size: 28),
          const SizedBox(height: 12),
          LText(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          LText(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ProspectoColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ProspectoColors.green, size: 27),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              LText(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ProspectoColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
