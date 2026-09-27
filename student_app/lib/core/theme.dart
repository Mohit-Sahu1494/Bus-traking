import 'package:flutter/material.dart';

class AppTheme {
  // University Navy palette
  static const primary = Color(0xFF0F2B48);
  static const primaryLight = Color(0xFF1E3A5F);
  static const accent = Color(0xFF2563EB); // Modern vibrant action blue
  static const accentLight = Color(0xFFEFF6FF); // Soft blue tint
  static const navy = Color(0xFF0A192F);

  // Status accents
  static const emerald = Color(0xFF059669);
  static const emeraldLight = Color(0xFFECFDF5);
  static const amber = Color(0xFFD97706);
  static const amberLight = Color(0xFFFEF3C7);
  static const coral = Color(0xFFDC2626);
  static const coralLight = Color(0xFFFEF2F2);
  static const muted = Color(0xFF64748B);
  static const mutedLight = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const surfaceBg = Color(0xFFF8FAFC);
  static const cardBg = Colors.white;

  // Consistent Radius Tokens
  static const double radiusButton = 12.0;
  static const double radiusCard = 18.0;
  static const double radiusPill = 999.0;
  static const double radiusSheet = 24.0;

  // Clean Subtle Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 20,
      offset: Offset(0, -4),
    ),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x180F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: surfaceBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: Colors.white,
        error: coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: coral),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accentLight,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 12);
          }
          return const TextStyle(color: muted, fontWeight: FontWeight.w500, fontSize: 12);
        }),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.4),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
        bodyMedium: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w400),
        labelSmall: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}
