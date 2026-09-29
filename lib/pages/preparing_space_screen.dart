import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logo_widget.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';

class PreparingSpaceScreen extends StatefulWidget {
  const PreparingSpaceScreen({
    super.key,
    required this.action,
    required this.successRoute,
  });

  final Future<void> Function() action;
  final String successRoute;

  static Future<void> open(
    BuildContext context, {
    required Future<void> Function() action,
    required String successRoute,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreparingSpaceScreen(
          action: action,
          successRoute: successRoute,
        ),
      ),
    );
  }

  @override
  State<PreparingSpaceScreen> createState() => _PreparingSpaceScreenState();
}

class _PreparingSpaceScreenState extends State<PreparingSpaceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final minimumDelay = Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      await Future.wait([widget.action(), minimumDelay]);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        widget.successRoute,
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
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
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final wave = math.sin(_controller.value * math.pi * 2);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, wave * 7),
                        child: Transform.scale(
                          scale: 1 + wave.abs() * .025,
                          child: const LogoWidget(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error == null) ...[
                        const LText(
                          'Préparation de votre espace…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: ProspectoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: ProspectoColors.green,
                          ),
                        ),
                      ] else ...[
                        const LText(
                          'Impossible de préparer cet espace',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: ProspectoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LText(
                          _friendlyError(_error!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ProspectoColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const LText('Revenir'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Bad state: ', '');
    return value.startsWith('Exception: ') ? value.substring(11) : value;
  }
}
