import 'package:easy_localization/easy_localization.dart';
import 'localized_text.dart';
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
    this.radius = 18,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = surfaceColor ?? cs.surface.withOpacity(isDark ? .68 : .84);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: cs.outline.withOpacity(.72)),
              borderRadius: BorderRadius.circular(radius),
            ),
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
