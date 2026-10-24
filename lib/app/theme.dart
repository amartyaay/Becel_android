import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0A0F0D);
  static const surface = Color(0xFF111916);
  static const surfaceHigh = Color(0xFF17211D);
  static const surfaceHigher = Color(0xFF202C26);
  static const border = Color(0xFF29372F);

  static const textPrimary = Color(0xFFF2F4EC);
  static const textSecondary = Color(0xFFA0ADA5);
  static const textTertiary = Color(0xFF8E9B92);

  static const green = Color(0xFFD0F477);
  static const yellow = Color(0xFFF5CC70);
  static const orange = Color(0xFFFFA66B);
  static const red = Color(0xFFFF806C);
  static const teal = Color(0xFF79D6C1);
  static const blue = Color(0xFF8EA9FF);
  static const violet = Color(0xFFB9A4FF);

  // Retained semantic names for detail screens while the app moves toward
  // the companion-first information architecture.
  static const recovery = green;
  static const sleep = blue;
  static const strain = red;
  static const stress = yellow;
  static const energy = teal;
  static const nutrition = green;
}

/// Central type scale for the redesigned interface.
///
/// Nothing rendered to users should go below 11 px. Numbers use tabular
/// figures so values never jitter between refreshes.
abstract final class AppType {
  static const eyebrow = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.3,
  );

  static const screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.35,
  );

  static const cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
  );

  static const rowTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13.5,
    height: 1.5,
  );

  static const note = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12.5,
    height: 1.45,
  );

  static const caption = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.4,
  );

  static const numXl = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 46,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numM = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numS = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const unit = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const footer = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  static const pill = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );
}

ThemeData buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.green,
    onPrimary: Color(0xFF17200B),
    secondary: AppColors.teal,
    onSecondary: Color(0xFF071C18),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.red,
    onError: Color(0xFF25100D),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: AppColors.surfaceHigh,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: const Color(0xFF101713),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.green.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.textTertiary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textTertiary,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: const Color(0xFF151F0A),
        disabledBackgroundColor: AppColors.surfaceHigher,
        disabledForegroundColor: AppColors.textTertiary,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green,
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
        color: AppColors.textPrimary,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  );
}
