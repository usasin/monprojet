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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey),
        ),
        child: Image.asset(asset, width: 40, height: 40),
      ),
    );
  }

  Future<void> _rateApp() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps&pcampaignid=web_share';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
      builder: (_) => AlertDialog(
        title: Text('Supprimer le compte'.tr()),
        content: Text('Cette action est irréversible. Confirmer ?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
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
            child: Text('Supprimer'.tr(),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final isDark    = themeProv.isDark;
    final cs        = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Dégradé
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.1),
                    cs.surfaceContainerHighest,
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const LogoWidget(),
                  const SizedBox(height: 10),

                  // QR code
                  QrImageView(
                    data:
                    'https://play.google.com/store/apps/details?id=com.ainego.ai_prospect_gps',
                    version: QrVersions.auto,
                    size: 140,
                    foregroundColor: cs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text('Scannez pour installer'.tr(),
                      style: TextStyle(color: cs.onSurfaceVariant)),

                  const Divider(height: 16),

                  // Thème
                  SwitchListTile(
                    title: Text(
                        isDark ? 'Thème sombre'.tr() : 'Thème clair'.tr()),
                    secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: cs.primary),
                    value: isDark,
                    onChanged: (_) => themeProv.toggleTheme(),
                  ),
                  const Divider(height: 1),

                  // À propos
                  ListTile(
                    leading: Icon(Icons.info_outline, color: cs.primary),
                    title: Text('À propos'.tr()),
                    onTap: () =>
                        Navigator.pushNamed(context, AboutScreen.routeName),
                  ),
                  const Divider(height: 1),

                  // RGPD
                  ListTile(
                    leading: Icon(Icons.privacy_tip, color: cs.primary),
                    title: Text('Informations RGPD'.tr()),
                    onTap: () =>
                        Navigator.pushNamed(context, InformationScreen.routeName),
                  ),
                  const Divider(height: 1),

                  // Langue
                  ListTile(
                    leading: Icon(Icons.language, color: cs.primary),
                    title: Text('Choisir la langue'.tr()),
                    onTap: _showLanguagePicker,
                  ),
                  const Divider(height: 1),

                  // Noter
                  ListTile(
                    leading: Icon(Icons.star, color: cs.primary),
                    title: Text('Noter l’application'.tr()),
                    onTap: _rateApp,
                  ),
                  const Divider(height: 1),

                  // Partager
                  ListTile(
                    leading: Icon(Icons.share, color: cs.primary),
                    title: Text('Partager l’application'.tr()),
                    onTap: _shareApp,
                  ),
                  const Divider(height: 1),

                  // Logout
                  ListTile(
                    leading: Icon(Icons.logout, color: cs.primary),
                    title: Text('Se déconnecter'.tr()),
                    onTap: _logout,
                  ),
                  const Divider(height: 1),

                  // Delete
                  ListTile(
                    leading:
                    const Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Supprimer le compte'.tr()),
                    onTap: _deleteAccount,
                  ),

                  const SizedBox(height: 20),
                  Text('Tous droits réservés © 2025'.tr(),
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('Conforme au RGPD de l’UE'.tr(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.home),
          label: Text('Accueil'.tr()),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, HomePage.routeName),
        ),
      ),
    );
  }
}
