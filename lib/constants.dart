import 'package:flutter/material.dart';

/// ライト/ダーク両対応のカラーパレット
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.white,
    required this.black,
    required this.gray,
    required this.darkGray,
    required this.surface,
    required this.userBubble,
    required this.aiBubble,
    required this.inputBg,
    required this.border,
    required this.accent,
    required this.background,
  });

  final Color white;
  final Color black;
  final Color gray;
  final Color darkGray;
  final Color surface;
  final Color userBubble;
  final Color aiBubble;
  final Color inputBg;
  final Color border;
  final Color accent;
  final Color background;

  static const light = AppColors(
    white: Color(0xFFFFFFFF),
    black: Color(0xFF1A1A2E),
    gray: Color(0xFFBDBDBD),
    darkGray: Color(0xFF757575),
    surface: Color(0xFFFFFFFF),
    userBubble: Color(0xFF4CAF50),
    aiBubble: Color(0xFFFFFFFF),
    inputBg: Color(0xFFF0F0F5),
    border: Color(0xFFE0E0E0),
    accent: Color(0xFF4CAF50),
    background: Color(0xFFF5F5FA),
  );

  static const dark = AppColors(
    white: Color(0xFFFFFFFF),
    black: Color(0xFFECECEC),
    gray: Color(0xFF8E8E93),
    darkGray: Color(0xFFAEAEB2),
    surface: Color(0xFF1C1C1E),
    userBubble: Color(0xFF3F9142),
    aiBubble: Color(0xFF2C2C2E),
    inputBg: Color(0xFF2C2C2E),
    border: Color(0xFF3A3A3C),
    accent: Color(0xFF66BB6A),
    background: Color(0xFF000000),
  );

  @override
  AppColors copyWith({
    Color? white,
    Color? black,
    Color? gray,
    Color? darkGray,
    Color? surface,
    Color? userBubble,
    Color? aiBubble,
    Color? inputBg,
    Color? border,
    Color? accent,
    Color? background,
  }) {
    return AppColors(
      white: white ?? this.white,
      black: black ?? this.black,
      gray: gray ?? this.gray,
      darkGray: darkGray ?? this.darkGray,
      surface: surface ?? this.surface,
      userBubble: userBubble ?? this.userBubble,
      aiBubble: aiBubble ?? this.aiBubble,
      inputBg: inputBg ?? this.inputBg,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      background: background ?? this.background,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      white: Color.lerp(white, other.white, t)!,
      black: Color.lerp(black, other.black, t)!,
      gray: Color.lerp(gray, other.gray, t)!,
      darkGray: Color.lerp(darkGray, other.darkGray, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      aiBubble: Color.lerp(aiBubble, other.aiBubble, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
    );
  }
}

/// `context.colors.xxx` で現在のテーマ（ライト/ダーク）に応じた色を取得
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData appTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: colors.accent,
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.black,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colors.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputBg,
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
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
