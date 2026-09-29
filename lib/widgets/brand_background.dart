// lib/widgets/brand_background.dart
import 'package:easy_localization/easy_localization.dart';
import 'localized_text.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/prospecto_colors.dart';

/// Fond animé Prospecto aligné sur la signature CIP.
/// Les mouvements et le flou existants sont conservés, avec une palette
/// bleu / vert / pêche plus légère et cohérente entre les applications.
class BrandBackground extends StatefulWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double blurSigma;
  final bool animate;

  const BrandBackground({
    super.key,
    required this.child,
    this.gradientColors = const [
      ProspectoColors.backgroundTop,
      ProspectoColors.blueMist,
      ProspectoColors.peachMist,
    ],
    this.blurSigma = 12,
    this.animate = true,
  });

  @override
  State<BrandBackground> createState() => _BrandBackgroundState();
}

class _BrandBackgroundState extends State<BrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant BrandBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate == widget.animate) return;
    if (widget.animate) {
      _ctrl.repeat();
    } else {
      // Fige le décor pendant les opérations lourdes plutôt que de continuer
      // à reconstruire/repeindre l'arrière-plan à chaque frame.
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [
            ProspectoColors.dark,
            Color(0xFF17283A),
            Color(0xFF18362F),
          ]
        : widget.gradientColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.8 + t, -1),
                  end: Alignment(1, 0.8 - t),
                  colors: colors,
                ),
              ),
            );
          },
        ),
        _blob(
          left: -90,
          top: -50,
          color: ProspectoColors.blue,
          opacity: isDark ? .18 : .16,
        ),
        _blob(
          right: -70,
          bottom: -70,
          color: ProspectoColors.green,
          opacity: isDark ? .17 : .14,
        ),
        _blob(
          right: -35,
          top: 140,
          color: ProspectoColors.peach,
          size: 150,
          opacity: isDark ? .15 : .13,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(
            color: isDark
                ? Colors.black.withOpacity(.08)
                : Colors.white.withOpacity(.10),
          ),
        ),
        const IgnorePointer(ignoring: true, child: SizedBox.shrink()),
        SizedBox.expand(child: widget.child),
      ],
    );
  }

  Widget _blob({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Color color,
    required double opacity,
    double size = 220,
  }) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = (1 - math.cos(2 * math.pi * _ctrl.value)) / 2;
        final animatedSize = size + 10 * (t - .5);
        return Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          child: Container(
            width: animatedSize,
            height: animatedSize,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(opacity + .04),
                  blurRadius: 80,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
