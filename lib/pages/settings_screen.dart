import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';
import 'home_page.dart';
import 'about_screen.dart';
import 'information_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _showLanguagePicker() async {
    final prefs = await SharedPreferences.getInstance();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir la langue'.tr()),
        content: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _langOption('fr', 'assets/images/france.png', prefs),
            _langOption('en', 'assets/images/united-kingdom.png', prefs),
          ],
        ),
      ),
    );
  }

  Widget _langOption(String code, String asset, SharedPreferences prefs) {
    return InkWell(
      onTap: () async {
        await prefs.setString('languageCode', code);
        if (mounted) {
          context.setLocale(Locale(code));
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E6E6)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0,2))],
        ),
        child: Image.asset(asset, width: 40, height: 28, fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps&pcampaignid=web_share',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() => Share.share(
    'Découvrez Prospecto – votre outil de prospection terrain :\n'
        'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps',
    subject: 'Prospecto',
  );

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Supprimer le compte'.tr()),
        content: Text('Cette action est irréversible. Confirmer ?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Annuler'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }
            },
            child: Text('Supprimer'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv  = context.watch<ThemeProvider>();
    final isDark     = themeProv.isDark;
    final theme      = themeProv.currentTheme;
    final cs         = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom; // <-- pour éviter le chevauchement

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
            title: Text('Paramètres'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
          ),

          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset), // <-- marge basse dynamique
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const LogoWidget(),
                  const SizedBox(height: 14),

                  // QR card
                  Card(
                    color: cs.surfaceContainerHighest.withOpacity(.95),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        children: [
                          QrImageView(
                            data: 'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps',
                            version: QrVersions.auto,
                            size: 140,
                            foregroundColor: cs.primary,
                          ),
                          const SizedBox(height: 8),
                          Text('Scannez pour installer'.tr(),
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _rateApp,
                                icon: const Icon(Icons.star_rate_rounded),
                                label: Text('Noter'.tr()),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _shareApp,
                                icon: const Icon(Icons.share_rounded),
                                label: Text('Partager'.tr()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // préférences
                  Card(
                    color: cs.surfaceContainerHighest.withOpacity(.95),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(isDark ? 'Thème sombre'.tr() : 'Thème clair'.tr()),
                          secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: cs.primary),
                          value: isDark,
                          onChanged: (_) => themeProv.toggleTheme(),
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: Icon(Icons.language_rounded, color: cs.primary),
                          title: Text('Choisir la langue'.tr()),
                          onTap: _showLanguagePicker,
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: Icon(Icons.info_outline_rounded, color: cs.primary),
                          title: Text('À propos'.tr()),
                          onTap: () => Navigator.pushNamed(context, AboutScreen.routeName),
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: Icon(Icons.privacy_tip_rounded, color: cs.primary),
                          title: Text('Informations RGPD'.tr()),
                          onTap: () => Navigator.pushNamed(context, InformationScreen.routeName),
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: Icon(Icons.logout_rounded, color: cs.primary),
                          title: Text('Se déconnecter'.tr()),
                          onTap: _logout,
                        ),
                        const Divider(height: 1),

                        ListTile(
                          leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                          title: Text('Supprimer le compte'.tr(), style: const TextStyle(color: Colors.red)),
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Tous droits réservés © 2025'.tr(), style: Theme.of(context).textTheme.bodySmall),
                  Text('Conforme au RGPD de l’UE'.tr(), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),

          bottomNavigationBar: SafeArea( // <-- protège des boutons/gestes système
            minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.home_rounded),
                label: Text('Accueil'.tr()),
                onPressed: () => Navigator.pushReplacementNamed(context, HomePage.routeName),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
