import 'package:flutter/material.dart';

class FcColors {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF1A1A2E);
  static const green = Color(0xFF4CAF50);
  static const skyblue = Color(0xFFF5F5FA);
  static const gray = Color(0xFFBDBDBD);
  static const darkGray = Color(0xFF757575);
  static const surface = Color(0xFFFFFFFF);
  static const userBubble = Color(0xFF4CAF50);
  static const aiBubble = Color(0xFFFFFFFF);
  static const inputBg = Color(0xFFF0F0F5);
  static const border = Color(0xFFE0E0E0);
  static const accent = Color(0xFF4CAF50);
}

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: FcColors.accent,
    brightness: Brightness.light,
    scaffoldBackgroundColor: FcColors.skyblue,
    appBarTheme: const AppBarTheme(
      backgroundColor: FcColors.surface,
      foregroundColor: FcColors.black,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: FcColors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: FcColors.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FcColors.accent,
        foregroundColor: FcColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FcColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FcColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
