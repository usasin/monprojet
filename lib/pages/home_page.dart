import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/theme_provider.dart';
import '../logo_widget.dart';
import 'select_prospects_page.dart';
import 'map_page.dart';
import 'reporting_page.dart';
import 'all_prospects_finished_page.dart';
import 'settings_screen.dart';

/// Fond quadrillé discret
class MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(.05)
      ..strokeWidth = 1;
    const step = 50.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page d'accueil avec boutons 3D esthétiques
class HomePage extends StatefulWidget {
  static const routeName = '/';
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static bool _adShown = false;
  InterstitialAd? _interstitial;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: ['6093B125AA558B88A894F10CE046FE69']),
    );
    _loadAd();
  }

  void _loadAd() {
    if (_adShown) return;
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1360261396564293/5482834887',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _ready = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (_, __) => ad.dispose(),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_ready && !_adShown) {
              _interstitial!.show();
              _adShown = true;
            }
          });
        },
        onAdFailedToLoad: (err) => debugPrint('❌ Interstitial failed: \$err'),
      ),
    );
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    super.dispose();
  }

  /// Bouton 3D avec icône dans un encadré coloré
  Widget _btn({
    required Color fill,
    required String assetPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PhysicalModel(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [fill.withOpacity(0.9), fill],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                // Icône encadrée
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: Colors.white70,
                    child: Center(
                      child: Image.asset(
                        assetPath,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.error, size: 32, color: fill),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Texte
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          offset: Offset(1, 1),
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 68),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: CustomPaint(
          painter: MapBackgroundPainter(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const LogoWidget(),
                  const SizedBox(height: 16),
                  Text(
                    'Prospecto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _btn(
                    fill: cs.primary,
                    assetPath: 'assets/icons/planifier.png',
                    label: 'Planifier'.tr(),
                    onTap: () => Navigator.pushNamed(context, SelectProspectsPage.routeName),
                  ),

                  _btn(
                    fill: cs.primary,
                    assetPath: 'assets/icons/carte.png',
                    label: 'Carte'.tr(),
                    onTap: () => Navigator.pushNamed(context, MapPage.routeName),
                  ),

                  _btn(
                    fill: cs.primary,
                    assetPath: 'assets/icons/report.png',
                    label: 'Reporting'.tr(),
                    onTap: () => Navigator.pushNamed(context, ReportingPage.routeName),
                  ),

                  _btn(
                    fill: cs.primary,
                    assetPath: 'assets/icons/historique.png',
                    label: 'Historique'.tr(),
                    onTap: () => Navigator.pushNamed(context, AllProspectsFinishedPage.routeName),
                  ),

                  _btn(
                    fill: cs.primary,
                    assetPath: 'assets/icons/parametres.png',
                    label: 'Paramètres'.tr(),
                    onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
                  ),


                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Tous droits réservés © 2025'.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Conforme au RGPD de l’UE'.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
