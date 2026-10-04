import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';
import '../widgets/localized_text.dart';

class InformationScreen extends StatelessWidget {
  static const routeName = '/information';
  const InformationScreen({super.key});

  static final Uri _privacy = Uri.parse(
    'https://github.com/usasin/monprojet/blob/main/docs/PRIVACY.md',
  );
  static final Uri _terms = Uri.parse(
    'https://digitalsolutionsai.com/conditions/',
  );
  static final Uri _website = Uri.parse('https://digitalsolutionsai.com/');
  static final Uri _contact = Uri(
    scheme: 'mailto',
    path: 'contact@digitalsolutionsai.com',
    queryParameters: {'subject': 'Prospecto — confidentialité et données'},
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
          ProspectoColors.greenMist,
          ProspectoColors.blueMist,
        ],
        blurSigma: 10,
        animate: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const LText(
              'Confidentialité & informations',
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
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: ProspectoColors.green.withOpacity(.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: ProspectoColors.green,
                                size: 29,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LText(
                              'Vos données, vos choix',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LText(
                              'Prospecto utilise les informations nécessaires au fonctionnement de la prospection, des tournées et du suivi commercial. Cette page présente simplement les principales données traitées, les services techniques utilisés et les contrôles disponibles.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface.withOpacity(.82),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _TrustChip(
                                  icon: Icons.gavel_rounded,
                                  label: 'RGPD',
                                ),
                                _TrustChip(
                                  icon: Icons.tune_rounded,
                                  label: 'Choix publicitaires',
                                ),
                                _TrustChip(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Suppression du compte',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.apartment_rounded,
                        title: 'Éditeur & contact',
                        body:
                            'Prospecto est une application Digital Solutions AI, Marseille • France. Pour une question liée à l’application, aux données ou à l’exercice de vos droits : contact@digitalsolutionsai.com.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.storage_rounded,
                        title: 'Données utilisées dans Prospecto',
                        body:
                            'Selon les fonctions que vous utilisez, Prospecto peut traiter les informations de compte, les prospects que vous créez ou sélectionnez, les tournées, rendez-vous, notes, statuts, relances, reportings et informations d’organisation nécessaires au mode Entreprise. Des données techniques limitées peuvent aussi être utilisées pour sécuriser le service et mémoriser vos droits d’accès ou d’abonnement.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.location_on_outlined,
                        title: 'Recherche de lieux & itinéraires',
                        body:
                            'La recherche de prospects et de lieux s’appuie notamment sur des données OpenStreetMap et des services associés tels que Nominatim et Overpass. Les requêtes nécessaires à une recherche peuvent inclure une zone, une adresse ou des coordonnées. L’ouverture d’un itinéraire peut ensuite utiliser une application cartographique externe choisie sur votre appareil.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.cloud_outlined,
                        title: 'Services techniques',
                        body:
                            'Prospecto utilise Firebase/Google pour l’authentification, les données, les fonctions serveur et les notifications ; Apple pour les achats intégrés iOS, Google Play pour les achats Android ; Google AdMob pour la publicité de la version gratuite ; OpenStreetMap/Nominatim/Overpass pour la recherche géographique ; et Stripe pour certains parcours Entreprise. Les droits d’achat sont validés côté serveur. La politique de confidentialité détaille ces traitements et les informations qui peuvent subsister après la suppression d’un compte.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.ads_click_rounded,
                        title: 'Publicité & abonnement',
                        body:
                            'La version gratuite peut afficher des publicités. Les choix de confidentialité publicitaire peuvent être ouverts depuis Paramètres lorsqu’ils sont disponibles. Les utilisateurs Premium ne reçoivent pas de publicité dans Prospecto. Les offres payantes servent également à débloquer les limites et fonctions prévues par le forfait choisi.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.groups_rounded,
                        title: 'Mode Entreprise',
                        body:
                            'Dans un espace Entreprise, certaines données commerciales peuvent être partagées avec les membres autorisés selon leur rôle. Les prospects d’entreprise, tournées attribuées, rendez-vous et reportings sont utilisés pour permettre le pilotage commercial prévu par le forfait et les droits configurés par l’administrateur.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoSection(
                        icon: Icons.manage_accounts_rounded,
                        title: 'Vos contrôles',
                        body:
                            'Vous pouvez modifier les informations accessibles dans l’application, gérer les choix publicitaires lorsqu’ils sont proposés et demander la suppression de votre compte depuis Paramètres. Vous pouvez aussi demander l’accès, la rectification, l’effacement, la limitation ou l’opposition lorsque ces droits s’appliquent en contactant Digital Solutions AI.',
                      ),
                      const SizedBox(height: 14),
                      FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              'Documents & assistance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LText(
                              'Consultez les documents officiels Digital Solutions AI ou contactez-nous directement.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: ProspectoColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _open(_privacy),
                                  icon: const Icon(Icons.privacy_tip_outlined),
                                  label: const LText(
                                    'Politique de confidentialité',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _open(_terms),
                                  icon: const Icon(Icons.description_outlined),
                                  label: const LText(
                                    'Conditions d’utilisation',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _open(_website),
                                  icon: const Icon(Icons.language_rounded),
                                  label: const LText('Site officiel'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _open(_contact),
                                  icon: const Icon(Icons.mail_outline_rounded),
                                  label: const LText('Contact'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      LText(
                        'Dernière mise à jour : septembre 2026',
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

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: ProspectoColors.green.withOpacity(.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProspectoColors.green.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ProspectoColors.green),
          const SizedBox(width: 6),
          LText(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ProspectoColors.blue.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: ProspectoColors.blue, size: 22),
          ),
          const SizedBox(width: 13),
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
                const SizedBox(height: 6),
                LText(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ProspectoColors.textSecondary,
                    height: 1.5,
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
