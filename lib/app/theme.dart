import 'package:flutter/material.dart';

/// Becel design tokens: light-first, soft and vivid.
///
/// An off-white canvas with white cards lifted by soft tinted shadows (no
/// hairline borders), very round corners, and saturated metric hues used
/// for rings and charts. The identity hues were validated as a set for
/// colour-vision deficiency on the white card surface (all six pass the
/// adjacent checks at ≥ 3:1; the on-screen trios pass all-pairs).
abstract final class AppColors {
  // Surfaces.
  static const bg = Color(0xFFF3F4F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFFFFFFF);

  /// Tracks, empty bars, input fills.
  static const surfaceHigher = Color(0xFFEDEFF4);
  static const border = Color(0xFFE5E7EE);
  static const hairline = Color(0x0F101828);

  static const textPrimary = Color(0xFF0E1116);
  static const textSecondary = Color(0xFF4A5160);
  static const textTertiary = Color(0xFF6B7282);

  /// Primary actions are ink-black pills; links use the steps blue.
  static const ink = Color(0xFF0E1116);
  static const accent = Color(0xFF1A8FE8);

  // Metric identities (fixed; never reused for status).
  static const strain = Color(0xFFF2601E);
  static const sleep = Color(0xFF6E56F0);
  static const burned = Color(0xFFCC7600);
  static const steps = Color(0xFF1A8FE8);
  static const active = Color(0xFFE8457A);
  static const intake = Color(0xFF14A06E);

  // Status: only when the colour means good / caution / bad, always with a
  // word beside it.
  static const bandGreen = Color(0xFF10A35A);
  static const bandYellow = Color(0xFFE29A00);
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

  /// Soft, cool-tinted elevation for cards (never grey or black).
  static const cardShadow = [
    BoxShadow(color: Color(0x0D1B2340), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A1B2340), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// A pale wash of a metric colour for chips and backgrounds.
  static Color tint(Color color, [double amount = 0.12]) =>
      Color.alphaBlend(color.withValues(alpha: amount), surface);
}

/// Type scale. Inter for text; Nunito (rounded) for numerals, which gives
/// scores a friendly, Bevel-like character. Labels stay quiet so values
/// carry the hierarchy.
abstract final class AppType {
  static const family = 'Inter';
  static const numerals = 'Nunito';

  /// Bundled subsets lack a few maths symbols (≤, ≈, ⅓).
  static const fallback = ['Roboto', 'sans-serif'];

  static const eyebrow = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const screenTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const cardTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const rowTitle = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 14.5,
    height: 1.5,
  );

  static const note = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 13.5,
    height: 1.45,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12.5,
    height: 1.4,
  );

  static const numXl = TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 52,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
  );

  static const numM = TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  static const numS = TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const unit = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const footer = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const pill = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

ThemeData buildLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceHigher,
    error: AppColors.bandRed,
    onError: Colors.white,
  );
  const buttonText = TextStyle(
    fontFamily: AppType.family,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppType.family,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigher,
        disabledForegroundColor: AppColors.textTertiary,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceHigher,
        side: BorderSide.none,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: buttonText,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.surfaceHigher,
      circularTrackColor: AppColors.surfaceHigher,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: AppType.family,
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigher,
      selectedColor: AppColors.ink,
      side: BorderSide.none,
      labelStyle: const TextStyle(fontFamily: AppType.family, fontSize: 13),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigher,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.surface,
    ),
  );
}
