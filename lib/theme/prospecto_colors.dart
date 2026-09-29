import 'package:flutter/material.dart';

/// Signature visuelle commune aux applications Digital Solutions AI.
/// Palette alignée sur CIP : bleu, vert, pêche, surfaces claires et texte ardoise.
class ProspectoColors {
  static const blue = Color(0xFF5AACDB);
  static const green = Color(0xFF3CC398);
  static const peach = Color(0xFFFBA49B);
  static const dark = Color(0xFF0F172A);

  static const backgroundTop = Color(0xFFF6FAFF);
  static const backgroundBottom = Color(0xFFF2F5FF);
  static const background = backgroundTop;
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);

  // Variantes utilisées pour conserver la richesse des animations de Prospecto.
  static const blueSoft = Color(0xFF8CCDEA);
  static const greenSoft = Color(0xFF8BE0C5);
  static const peachSoft = Color(0xFFFFC8C2);
  static const blueMist = Color(0xFFDDEFFA);
  static const greenMist = Color(0xFFDDF7EE);
  static const peachMist = Color(0xFFFFE7E4);

  static const brandGradient = LinearGradient(
    colors: [blue, green, peach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryGradient = LinearGradient(
    colors: [blue, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const digitalGradient = LinearGradient(
    colors: [backgroundTop, backgroundBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
