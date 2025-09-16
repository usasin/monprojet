// lib/widgets/brand_background.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class BrandBackground extends StatefulWidget {
  final Widget child;

  /// Personnalisation optionnelle
  final List<Color> gradientColors;   // 3 couleurs min conseillées
  final double blurSigma;             // intensité du flou
  final bool animate;                 // active l’animation douce

  const BrandBackground({
    Key? key,
    required this.child,
    this.gradientColors = const [Color(0xFFE9EBF6), Color(0xFF313659), Color(
        0xFFFFFFFF)],
    this.blurSigma = 12,
    this.animate = true,
  }) : super(key: key);

  @override
  State<BrandBackground> createState() => _BrandBackgroundState();
}

class _BrandBackgroundState extends State<BrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand, // ← remplit l’écran
      children: [
        // Dégradé animé très léger
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = widget.animate ? _ctrl.value : 0.0;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.8 + t, -1),
                  end: Alignment(1, 0.8 - t),
                  colors: widget.gradientColors,
                ),
              ),
            );
          },
        ),

        // Blobs (aucun Positioned imbriqué → pas de crash ParentData)
        _blob(left: -80, top: -40, color: const Color(0xFF7F5AF0)),
        _blob(right: -60, bottom: -60, color: const Color(0xFF2CB67D)),
        _blob(right: -30, top: 140, color: const Color(0xFF00C2FF), size: 140),

        // Flou/verre
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(color: Colors.black.withOpacity(0.15)),
        ),

        // Contenu de la page
        // SizedBox.expand évite toute erreur de ParentData et s’adapte à tous formats
        IgnorePointer(
          ignoring: true, // le fond n’intercepte pas les taps
          child: const SizedBox.shrink(),
        ),
        SizedBox.expand(child: widget.child),
      ],
    );
  }

  Widget _blob({double? left, double? top, double? right, double? bottom,
    required Color color, double size = 220}) {
    // animation de “respiration” discrète
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = (1 - math.cos(2 * math.pi * _ctrl.value)) / 2; // 0..1
        final s = size + 10 * (t - .5);
        return Positioned(
          left: left, top: top, right: right, bottom: bottom,
          child: Container(
            width: s, height: s,
            decoration: BoxDecoration(
              color: color.withOpacity(0.22),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 80, spreadRadius: 40,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
