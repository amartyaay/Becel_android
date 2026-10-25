import 'package:flutter/material.dart';

/// Becel design tokens: light-first, soft and vivid, with a matching dark
/// palette.
///
/// Light: an off-white canvas with white cards lifted by soft tinted shadows
/// (no hairline borders), very round corners, and saturated metric hues used
/// for rings and charts. Dark: the same layout on a deep, slightly cool
/// near-black, with cards a step lighter instead of shadows. The identity
/// hues were validated as a set for colour-vision deficiency on both card
/// surfaces.
///
/// Neutral tokens are getters so the whole app can switch palettes at
/// runtime ([AppColors.useDark]); metric and status hues are fixed.
abstract final class AppColors {
  static bool _dark = false;

  /// Switches every neutral token. The app rebuilds after calling this.
  static void useDark(bool dark) => _dark = dark;
  static bool get isDark => _dark;

  // Surfaces.
  static Color get bg => _dark ? const Color(0xFF0B0D12) : const Color(0xFFF3F4F8);
  static Color get surface =>
      _dark ? const Color(0xFF161A22) : const Color(0xFFFFFFFF);
  static Color get surfaceHigh =>
      _dark ? const Color(0xFF1C212B) : const Color(0xFFFFFFFF);

  /// Tracks, empty bars, input fills.
  static Color get surfaceHigher =>
      _dark ? const Color(0xFF252B36) : const Color(0xFFEDEFF4);
  static Color get border =>
      _dark ? const Color(0xFF2C3340) : const Color(0xFFE5E7EE);
  static Color get hairline =>
      _dark ? const Color(0x14FFFFFF) : const Color(0x0F101828);

  static Color get textPrimary =>
      _dark ? const Color(0xFFF2F4F8) : const Color(0xFF0E1116);
  static Color get textSecondary =>
      _dark ? const Color(0xFFB4BBC8) : const Color(0xFF4A5160);
  static Color get textTertiary =>
      _dark ? const Color(0xFF8A93A3) : const Color(0xFF6B7282);

  /// Primary actions are ink pills (black on light, white on dark); text
  /// on them uses [onInk]. Links use the steps blue.
  static Color get ink =>
      _dark ? const Color(0xFFF2F4F8) : const Color(0xFF0E1116);
  static Color get onInk =>
      _dark ? const Color(0xFF0B0D12) : const Color(0xFFFFFFFF);
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

  /// Soft, cool-tinted elevation for cards (never grey or black). On dark,
  /// cards separate by surface tone, so the shadow is only a faint lift.
  static List<BoxShadow> get cardShadow => _dark
      ? const [
          BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
        ]
      : const [
          BoxShadow(color: Color(0x0D1B2340), blurRadius: 24, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x0A1B2340), blurRadius: 3, offset: Offset(0, 1)),
        ];

  /// A pale wash of a metric colour for chips and backgrounds (a deeper
  /// wash on dark so it still reads).
  static Color tint(Color color, [double amount = 0.12]) => Color.alphaBlend(
    color.withValues(alpha: _dark ? amount * 1.6 : amount),
    surface,
  );
}
abstract final class AppType {
  static const family = 'Inter';
  static const numerals = 'Nunito';

  /// Bundled subsets lack a few maths symbols (≤, ≈, ⅓).
  static const fallback = ['Roboto', 'sans-serif'];

  static TextStyle get eyebrow => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle get screenTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  static TextStyle get sectionTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle get cardTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle get rowTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static TextStyle get body => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 14.5,
    height: 1.5,
  );

  static TextStyle get note => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textSecondary,
    fontSize: 13.5,
    height: 1.45,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12.5,
    height: 1.4,
  );

  static TextStyle get numXl => TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 52,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
  );

  static TextStyle get numM => TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  static TextStyle get numS => TextStyle(
    fontFamily: numerals,
    fontFamilyFallback: fallback,
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static TextStyle get unit => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get footer => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get pill => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

/// Material theme for the active palette ([AppColors.useDark]).
ThemeData buildAppTheme() {
  final dark = AppColors.isDark;
  final colorScheme = (dark ? const ColorScheme.dark() : const ColorScheme.light())
      .copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.onInk,
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
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.onInk,
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
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.surfaceHigher,
      circularTrackColor: AppColors.surfaceHigher,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: AppType.family,
        color: AppColors.onInk,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.onInk
            : AppColors.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.ink
            : AppColors.surfaceHigher,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigher,
      selectedColor: AppColors.ink,
      side: BorderSide.none,
      labelStyle: TextStyle(
        fontFamily: AppType.family,
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: AppType.family,
        fontSize: 13,
        color: AppColors.onInk,
      ),
      checkmarkColor: AppColors.onInk,
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
        borderSide: BorderSide(color: AppColors.ink, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.surface),
  );
}