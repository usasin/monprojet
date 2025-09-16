import 'dart:ui';
import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool animate;
  final double blur;
  final double blobOpacity;
  final bool vignette;
  final double vignetteOpacity;
  final Color? baseColor;

  const AuroraBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.blur = 24,
    this.blobOpacity = .55,
    this.vignette = true,
    this.vignetteOpacity = .07,
    this.baseColor,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color base = widget.baseColor ?? cs.surface;
    double o  = widget.blobOpacity.clamp(0, 1);

    Widget blob(Color color, Alignment a1, Alignment a2, double size) {
      final align = widget.animate ? Alignment.lerp(a1, a2, _c.value)! : a1;
      return Align(
        alignment: align,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(o), color.withOpacity(0)],
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: base),
        blob(cs.primary,   const Alignment(-1.2, -1.0), const Alignment(-.7, -.9), 420),
        blob(cs.tertiary,  const Alignment( 1.1,  .9), const Alignment( .6,  .6), 540),
        blob(cs.secondary, const Alignment(-.8,   .8), const Alignment(-.4, .5),  380),
        if (widget.vignette)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.2,
                center: const Alignment(0, .2),
                colors: [
                  const Color(0x00000000),
                  Colors.black.withOpacity(widget.vignetteOpacity),
                ],
              ),
            ),
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: const SizedBox.expand(),
        ),
        widget.child,
      ],
    );
  }
}

class GradientText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final List<Color>? colors;
  final double speedSeconds;
  const GradientText(this.text, {super.key, this.style, this.colors, this.speedSeconds = 8});
  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: Duration(seconds: widget.speedSeconds.toInt()))..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = widget.colors ?? [cs.primary, cs.tertiary, cs.secondary];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            final dx = bounds.width * t;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds.shift(Offset(dx, 0)));
          },
          child: Text(
            widget.text,
            style: (widget.style ?? DefaultTextStyle.of(context).style).copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;
  final BorderSide? border;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
    this.blur = 20,
    this.opacity = .08,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: cs.onSurface.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.fromBorderSide(border ?? BorderSide(color: cs.outlineVariant.withOpacity(.4))),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const PressableScale({super.key, required this.child, this.onTap, this.scale = .97});
  @override
  State<PressableScale> createState() => _PressableScaleState();
}
class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class FadeSlide extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double dy;
  const FadeSlide({super.key, required this.child, this.duration = const Duration(milliseconds: 500), this.curve = Curves.easeOut, this.dy = 12});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: child),
        );
      },
    );
  }
}
