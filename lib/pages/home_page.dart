// lib/pages/home_page.dart
import 'dart:math' as math;

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

// même fond que le Login
import '../widgets/brand_background.dart';
// micro-interactions (tap scale)
import '../ui/bling.dart';

/// Quadrillage discret
class MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(.04)
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

class HomePage extends StatefulWidget {
  static const routeName = '/';
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static bool _adShown = false;
  InterstitialAd? _interstitial;
  bool _ready = false;

  // douce anim du logo (comme le login)
  late final AnimationController _logoCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 5),
  )..repeat();
  late final Animation<double> _logoT = CurvedAnimation(
    parent: _logoCtrl, curve: Curves.easeInOutSine,
  );

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
        onAdFailedToLoad: (err) => debugPrint('❌ Interstitial failed: $err'),
      ),
    );
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  /// Bouton premium (icônes Material Symbols Rounded)
  Widget _navButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    List<Color>? gradient,
  }) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final h = isTablet ? 80.0 : 68.0;
    final r = isTablet ? 24.0 : 22.0;

    final grad = gradient ?? const [Color(0xFF0E2A66), Color(0xFF7A8CEB)];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: grad, begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(r),
            boxShadow: [BoxShadow(color: grad.last.withOpacity(.30), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              // Bloc icône à gauche (clair)
              Container(
                width: h,
                height: h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.90),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r),
                    bottomLeft: Radius.circular(r),
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: isTablet ? 34 : 30, color: grad.first),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 2, offset: Offset(1,1), color: Colors.black26)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    final size      = MediaQuery.of(context).size;
    final shortest  = size.shortestSide;
    final isTablet  = shortest >= 600;
    final isDesktop = size.width >= 1024;
    final maxW      = isDesktop ? 900.0 : (isTablet ? 720.0 : 560.0);

    // anim logo (corrigé : on utilise math.sin)
    final t   = _logoT.value * 2 * math.pi;
    final s   = math.sin(t);
    final dy  = s * 6.0;
    final rot = s * .04;
    final scl = 1.0 + (s * .015);

    return Theme(
      data: theme,
      child: BrandBackground(
        // même palette claire que le Login
        gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
        blurSigma: 16,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomPaint(
            painter: MapBackgroundPainter(),
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        // Logo animé + ombre
                        AnimatedBuilder(
                          animation: _logoT,
                          builder: (_, __) => Column(
                            children: [
                              Transform.translate(
                                offset: Offset(0, dy),
                                child: Transform.rotate(
                                  angle: rot,
                                  child: Transform.scale(
                                    scale: scl,
                                    child: const LogoWidget(),
                                  ),
                                ),
                              ),
                              Container(
                                width: 88,
                                height: 10,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.14 - .05 * s.abs()),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Titre lisible (bleu dark)
                        Text(
                          'Prospecto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 40 : 32,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0E2A66),
                            shadows: const [Shadow(blurRadius: 6, offset: Offset(0,2), color: Colors.black26)],
                          ),
                        ),

                        const SizedBox(height: 20),

                        _navButton(
                          label: 'Planifier'.tr(),
                          icon: Icons.calendar_month_rounded,
                          onTap: () => Navigator.pushNamed(context, SelectProspectsPage.routeName),
                        ),
                        _navButton(
                          label: 'Carte'.tr(),
                          icon: Icons.map_rounded,
                          onTap: () => Navigator.pushNamed(context, MapPage.routeName),
                        ),
                        _navButton(
                          label: 'Reporting'.tr(),
                          icon: Icons.analytics_rounded,
                          onTap: () => Navigator.pushNamed(context, ReportingPage.routeName),
                        ),
                        _navButton(
                          label: 'Historique'.tr(),
                          icon: Icons.history_rounded,
                          onTap: () => Navigator.pushNamed(context, AllProspectsFinishedPage.routeName),
                        ),
                        _navButton(
                          label: 'Paramètres'.tr(),
                          icon: Icons.settings_rounded,
                          onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
                        ),

                        const SizedBox(height: 24),
                        Center(child: Text('Tous droits réservés © 2025'.tr(), style: theme.textTheme.bodySmall)),
                        const SizedBox(height: 6),
                        Center(child: Text('Conforme au RGPD de l’UE'.tr(), style: theme.textTheme.bodySmall)),
                        const SizedBox(height: 8),
                      ],
                    ),
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
