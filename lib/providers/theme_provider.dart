import 'package:flutter/material.dart';

import '../theme/prospecto_colors.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: ProspectoColors.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: ProspectoColors.blue,
    onPrimary: Colors.white,
    secondary: ProspectoColors.green,
    onSecondary: Colors.white,
    tertiary: ProspectoColors.peach,
    onTertiary: ProspectoColors.dark,
    surface: ProspectoColors.surface,
    onSurface: ProspectoColors.textPrimary,
    outline: ProspectoColors.border,
    error: const Color(0xFFEF4444),
    onError: Colors.white,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: ProspectoColors.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: ProspectoColors.blueSoft,
    onPrimary: ProspectoColors.dark,
    secondary: ProspectoColors.green,
    onSecondary: ProspectoColors.dark,
    tertiary: ProspectoColors.peach,
    onTertiary: ProspectoColors.dark,
    surface: const Color(0xFF172033),
    onSurface: const Color(0xFFF8FAFC),
    outline: const Color(0xFF334155),
    error: const Color(0xFFF87171),
    onError: ProspectoColors.dark,
  );

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
    },
  );

  ThemeData _buildTheme(ColorScheme scheme, {required bool dark}) {
    final surface = dark ? const Color(0xFF172033) : ProspectoColors.surface;
    final scaffold = dark ? ProspectoColors.dark : ProspectoColors.background;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface.withOpacity(dark ? .90 : .96),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),

      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w900),
        titleMedium: TextStyle(fontWeight: FontWeight.w800),
        bodyMedium: TextStyle(height: 1.25),
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),

      cardTheme: CardThemeData(
        color: surface.withOpacity(dark ? .78 : .92),
        elevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline.withOpacity(.75)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          disabledBackgroundColor: scheme.secondary.withOpacity(.35),
          disabledForegroundColor: scheme.onSecondary.withOpacity(.72),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withOpacity(dark ? .76 : .96),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurface.withOpacity(.70),
          fontWeight: FontWeight.w700,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withOpacity(.08),
        selectedColor: scheme.secondary.withOpacity(.18),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface.withOpacity(.76)),
    );
  }

  late final ThemeData _light = _buildTheme(_lightScheme, dark: false);
  late final ThemeData _dark = _buildTheme(_darkScheme, dark: true);

  ThemeData get currentTheme => _isDark ? _dark : _light;
}
