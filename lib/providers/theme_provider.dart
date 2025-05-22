import 'package:flutter/material.dart';

/// Palette 2025
const Color kLogoRed  = Color(0xFFCA0C0A);      // rouge “tie” du logo
const Color kIndigo   = Color(0xFF052C6C);      // Indigo 800 (material)
const Color kBeige    = Color(0xFFFAF7F2);      // fond très clair

Color _darken(Color c, [double a = .25]) {
  final f = 1 - a;
  return Color.fromARGB(c.alpha, (c.red*f).round(), (c.green*f).round(), (c.blue*f).round());
}

class ThemeProvider with ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggleTheme() { _isDark = !_isDark; notifyListeners(); }

  /*──────────── Thème clair ───────────*/
  ThemeData get _light {
    final cs = ColorScheme.fromSeed(
      brightness : Brightness.light,
      seedColor  : kIndigo,
      background : kBeige,
    );
    return ThemeData(
      useMaterial3: true,
      brightness : Brightness.light,
      scaffoldBackgroundColor: kBeige,
      colorScheme: cs,
      iconTheme  : const IconThemeData(color: kLogoRed),
      appBarTheme: const AppBarTheme(
        backgroundColor: kIndigo,
        foregroundColor: Colors.white,
        iconTheme      : IconThemeData(color: Colors.white),
      ),

      /*– Boutons –*/
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kIndigo,
          foregroundColor: Colors.white,
          side: const BorderSide(color: kLogoRed, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kIndigo,
          foregroundColor: Colors.white,
          side: const BorderSide(color: kLogoRed, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kIndigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  /*──────────── Thème sombre ───────────*/
  ThemeData get _dark {
    final indigoDark = _darken(kIndigo, .30);
    final cs = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor : indigoDark,
      background: _darken(kBeige, .85),
    );
    return ThemeData(
      useMaterial3: true,
      brightness : Brightness.dark,
      scaffoldBackgroundColor: cs.background,
      colorScheme: cs,
      iconTheme  : const IconThemeData(color: kLogoRed),
      appBarTheme: AppBarTheme(
        backgroundColor: indigoDark,
        foregroundColor: Colors.white,
        iconTheme      : const IconThemeData(color: Colors.white),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: indigoDark,
          foregroundColor: Colors.white,
          side: const BorderSide(color: kLogoRed, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: indigoDark,
          foregroundColor: Colors.white,
          side: const BorderSide(color: kLogoRed, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: indigoDark,
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData get currentTheme => _isDark ? _dark : _light;
}
