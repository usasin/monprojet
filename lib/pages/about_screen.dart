import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs    = theme.colorScheme;

    // Firestore: doc "about prospecto" dans la collection "about"
    final docStream = FirebaseFirestore.instance
        .collection('about')
        .doc('about prospecto')
        .snapshots();

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('À propos', style: TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
          ),

          body: SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: docStream,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: _ErrorCard(
                      message: 'Erreur de chargement',
                      onRetry: () {}, // stream se recharge automatiquement
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data?.data() as Map<String, dynamic>?;
                if (data == null) {
                  return const Center(child: _ErrorCard(message: 'Aucune donnée disponible'));
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Card(
                        color: cs.surfaceContainerHighest.withOpacity(.95),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Titre
                              Text(
                                (data['title'] as String?) ?? 'Prospecto',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Sous-titre
                              if (data['description'] != null)
                                Text(
                                  data['description'] as String,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // Logo
                              const LogoWidget(),
                              const SizedBox(height: 20),

                              // Contenu HTML
                              Html(
                                data: (data['content'] as String?) ?? '<p>Contenu indisponible</p>',
                                style: {
                                  'body'  : Style(color: cs.onSurface, fontSize: FontSize(16)),
                                  'h1'    : Style(color: cs.onSurface, fontWeight: FontWeight.w800),
                                  'h2'    : Style(color: cs.onSurface, fontWeight: FontWeight.w700),
                                  'strong': Style(color: cs.primary, fontWeight: FontWeight.w700),
                                  'a'     : Style(color: cs.secondary, textDecoration: TextDecoration.underline),
                                  'ul'    : Style(margin: Margins.only(left: 16)),
                                },
                                onLinkTap: (url, _, __) async {
                                  if (url == null) return;
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),

                              const SizedBox(height: 20),
                              Text('© 2025 – Prospecto', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest.withOpacity(.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: cs.primary),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
