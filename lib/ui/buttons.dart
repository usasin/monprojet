import 'package:flutter/material.dart';
import 'bling.dart'; // ← réutilise Glass + PressableScale

enum ButtonSize { compact, regular, large }

double _btnHeight(ButtonSize s) {
  switch (s) {
    case ButtonSize.compact: return 56;
    case ButtonSize.large:   return 84;
    case ButtonSize.regular:
    default: return 68;
  }
}

double _radius(ButtonSize s) {
  switch (s) {
    case ButtonSize.compact: return 18;
    case ButtonSize.large:   return 24;
    case ButtonSize.regular:
    default: return 22;
  }
}

/// Bouton principal: fond dégradé + carte glass + micro-interaction (tap scale)
class GradientGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonSize size;
  final IconData? icon;
  final String? asset; // alternative à icon
  final List<Color>? colors;

  const GradientGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.regular,
    this.icon,
    this.asset,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h   = _btnHeight(size);
    final r   = _radius(size);
    final g   = colors ?? [cs.primary.withOpacity(.95), cs.primary];

    return PressableScale(
      onTap: onPressed,
      child: Glass(
        radius: r,
        padding: EdgeInsets.zero,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(r),
          ),
          child: Row(
            children: [
              // Zone icône à gauche (carrée = h x h)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r),
                  bottomLeft: Radius.circular(r),
                ),
                child: Container(
                  width: h,
                  height: h,
                  color: Colors.white70,
                  child: Center(
                    child: asset != null
                        ? Image.asset(
                      asset!,
                      width: size == ButtonSize.large ? 38 : 32,
                      height: size == ButtonSize.large ? 38 : 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        icon ?? Icons.apps, size: 28, color: g.last,
                      ),
                    )
                        : Icon(icon ?? Icons.apps, size: 28, color: g.last),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Libellé
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
                    shadows: [Shadow(blurRadius: 2, offset: Offset(1,1), color: Colors.black26)],
                  ),
                ),
              ),

              const SizedBox(width: 12),
              SizedBox(width: 12), // équilibre visuel
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire: bordure dégradée + fond neutre (tonal)
class OutlineGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonSize size;
  final IconData? icon;
  final List<Color>? colors;
  final Color? background;

  const OutlineGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.regular,
    this.icon,
    this.colors,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h  = _btnHeight(size);
    final r  = _radius(size);

    final grad = colors ?? [cs.tertiary, cs.secondary, cs.primary];

    return PressableScale(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(r),
        ),
        padding: const EdgeInsets.all(1.8), // épaisseur de bord
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: background ?? cs.surface.withOpacity(.8),
            borderRadius: BorderRadius.circular(r - .5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: cs.onSurface, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton icon-only circulaire (glass)
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Glass(
        radius: size/2,
        padding: EdgeInsets.zero,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon),
        ),
      ),
    );
  }
}
