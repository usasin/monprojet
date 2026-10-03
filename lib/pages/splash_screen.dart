import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logo_widget.dart';
import '../providers/org_provider.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import 'home_page.dart';
import 'org_mode_gate.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _preparing = true);

    final user = FirebaseAuth.instance.currentUser;
    String destination = OrgModeGate.routeName;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (!mounted) return;
        final provider = context.read<OrgProvider>();
        await provider.loadFromUser(user.uid);
        destination = HomePage.routeName;
      } catch (_) {
        destination = HomePage.routeName;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(destination, (_) => false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final wave = math.sin(_controller.value * math.pi * 2);
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, wave * 7),
                        child: Transform.rotate(
                          angle: wave * .035,
                          child: Transform.scale(
                            scale: 1 + wave.abs() * .025,
                            child: const LogoWidget(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const LText(
                        'Prospectez mieux. Avancez plus vite.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: ProspectoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _preparing
                            ? Column(
                                key: const ValueKey('preparing'),
                                children: [
                                  const LText(
                                    'Préparation de votre espace…',
                                    style: TextStyle(
                                      color: ProspectoColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (FirebaseAuth.instance.currentUser != null) ...[
                                    const SizedBox(height: 6),
                                    LText(
                                      FirebaseAuth.instance.currentUser!.isAnonymous
                                          ? 'Compte : session invitée'
                                          : 'Compte : ${FirebaseAuth.instance.currentUser!.email ?? FirebaseAuth.instance.currentUser!.displayName ?? 'Prospecto'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ProspectoColors.blue,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: ProspectoColors.green,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(
                                key: ValueKey('empty'),
                                height: 56,
                              ),
                      ),
                    ],
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
