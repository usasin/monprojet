import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs    = theme.colorScheme;

    final docStream =
    FirebaseFirestore.instance.collection('about').doc('about prospecto').snapshots();

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title           : const Text('À propos'),
          backgroundColor : cs.primary,
          foregroundColor : cs.onPrimary,
        ),

        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin : Alignment.topCenter,
              end   : Alignment.bottomCenter,
              colors : [cs.primary.withOpacity(.05), cs.surface],
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: docStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Erreur de chargement'));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data?.data() as Map<String, dynamic>?;

              if (data == null) {
                return const Center(child: Text('Aucune donnée disponible'));
              }

              /*────────── Contenu ─────────*/
              return SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    /*— Titre —*/
                    Text(
                      data['title'] ?? 'Prospecto',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    /*— Sous-titre —*/
                    if (data['description'] != null)
                      Text(
                        data['description'],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium!
                            .copyWith(color: cs.primary),
                      ),
                    const SizedBox(height: 24),

                    /*— Logo —*/
                    const LogoWidget(),
                    const SizedBox(height: 24),

                    /*— HTML Firestore —*/
                    Html(
                      data: data['content'] ?? '<p>Contenu indisponible</p>',
                      style: {
                        'body'  : Style(color: cs.onSurface),
                        'h1,h2' : Style(color: cs.onSurface, fontWeight: FontWeight.bold),
                        'strong': Style(color: cs.primary),
                        'a'     : Style(color: cs.secondary),
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '© 2025 – Prospecto',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
