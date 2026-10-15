/// Design system for Day One: No Contact.
///
/// Warm, healing palette. NO blue anywhere — brand rule.
/// Cream backgrounds, terracotta primary, charcoal text.
library;

import 'package:flutter/material.dart';

class DayOneColors {
  DayOneColors._();

  static const cream = Color(0xFFFAF6F1);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2D2A26);
  static const muted = Color(0xFF8A8178);
  static const faint = Color(0xFFB4ABA0);
  static const line = Color(0xFFEDE6DD);
  static const cardBorder = Color(0xFFF1EAE2);

  static const terracotta = Color(0xFFD96C47);
  static const terracottaDeep = Color(0xFFB8552F);
  static const terracottaSoft = Color(0xFFF5E6DC);
  static const terracottaPale = Color(0xFFFDEEE4);

  static const sage = Color(0xFF5F9E6E);
  static const sageSoft = Color(0xFFE6F2E9);

  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFFFF7EF);
  static const goldBorder = Color(0xFFE8C89F);

  static const sos = Color(0xFFC0392B);

  static const lockedBg = Color(0xFFF4F1EC);
  static const lockedBorder = Color(0xFFE4DED4);
  static const lockedText = Color(0xFFA39A8D);
}

class DayOneTheme {
  DayOneTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DayOneColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DayOneColors.terracotta,
        primary: DayOneColors.terracotta,
        surface: DayOneColors.cream,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DayOneColors.cream,
        foregroundColor: DayOneColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: DayOneColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'Fraunces',
            color: DayOneColors.ink,
            fontSize: 54,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            fontFamily: 'Fraunces',
            color: DayOneColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3),
        titleMedium: TextStyle(
            color: DayOneColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(
            color: DayOneColors.ink, fontSize: 13.5, height: 1.5),
        bodySmall: TextStyle(color: DayOneColors.muted, fontSize: 12),
        labelSmall: TextStyle(
            color: DayOneColors.terracottaDeep,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DayOneColors.terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DayOneColors.terracotta,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: Color(0xFFEAD9CC), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: DayOneColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: DayOneColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DayOneColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DayOneColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: DayOneColors.terracotta, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: DayOneColors.terracotta,
        unselectedItemColor: DayOneColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
