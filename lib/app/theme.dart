import 'package:flutter/material.dart';

/// Becel design tokens.
///
/// Dark-first: a cool near-black canvas with four tonal surface steps and
/// hairline borders for depth (no grey drop shadows). Metric identity hues
/// were validated as a set for colour-vision deficiency against the card
/// surface (OKLab ΔE ≥ 8 adjacent; the on-screen trios pass all-pairs).
abstract final class AppColors {
  // Surfaces, darkest to lightest.
  static const bg = Color(0xFF0A0B0E);
  static const surface = Color(0xFF111318);
  static const surfaceHigh = Color(0xFF171A20);
  static const surfaceHigher = Color(0xFF20242C);
  static const border = Color(0xFF242932);
  static const hairline = Color(0x14FFFFFF);

  static const textPrimary = Color(0xFFF4F5F7);
  static const textSecondary = Color(0xFFA7ADB9);
  static const textTertiary = Color(0xFF7A8190);

  /// Interactive accent: links, selected navigation, primary buttons.
  static const accent = Color(0xFF5B93FF);

  // Metric identities (fixed; never reused for status).
  static const strain = Color(0xFFE8632A);
  static const sleep = Color(0xFF8573EE);
  static const burned = Color(0xFFC08400);
  static const intake = Color(0xFF13A374);
  static const steps = Color(0xFF3D80F2);

  // Status (reserved: only when the colour means good / caution / bad, and
  // always paired with a word).
  static const bandGreen = Color(0xFF17B26A);
  static const bandYellow = Color(0xFFF5B100);
  static const bandRed = Color(0xFFE5484D);

  // Short aliases used across screens.
  static const green = bandGreen;
  static const yellow = bandYellow;
  static const red = bandRed;
  static const orange = strain;
  static const teal = intake;
  static const blue = steps;
  static const violet = sleep;
  static const recovery = bandGreen;
  static const energy = burned;
  static const strainBlue = strain;
}

/// Type scale: Inter, four working sizes plus display numerals. Labels stay
/// quiet so values carry the hierarchy.
abstract final class AppType {
  static const family = 'Inter';

  /// Inter's bundled Latin subset lacks some maths symbols (≤, ≈, ⅓).
  static const fallback = ['Roboto', 'sans-serif'];

  static const eyebrow = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const screenTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
  );

  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const cardTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const rowTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.5,
  );

  static const note = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.45,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.4,
  );

  /// Hero numerals: proportional figures read tighter at display sizes.
  static const numXl = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 48,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.0,
  );

  static const numM = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 26,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
  );

  static const numS = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const unit = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const footer = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const pill = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}

ThemeData buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.intake,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceHigher,
    error: AppColors.bandRed,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppType.family,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigher,
        disabledForegroundColor: AppColors.textTertiary,
        textStyle: const TextStyle(
          fontFamily: AppType.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceHigh,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(
          fontFamily: AppType.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(
          fontFamily: AppType.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceHigher,
      circularTrackColor: AppColors.surfaceHigher,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigher,
      contentTextStyle: const TextStyle(
        fontFamily: AppType.family,
        color: AppColors.textPrimary,
        fontSize: 13.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontFamily: AppType.family, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigher,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}
