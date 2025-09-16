import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? surfaceColor;

  const FrostedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.radius = 24,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = surfaceColor ?? Colors.white.withOpacity(0.10);

    return Container(
      margin: margin,
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white.withOpacity(0.20)),
              borderRadius: BorderRadius.circular(radius),
            ),
            // ⬇️ This Material fixes "No Material widget found" for InkWell
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
