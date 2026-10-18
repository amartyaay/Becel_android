import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0A0F0D);
  static const surface = Color(0xFF111916);
  static const surfaceHigh = Color(0xFF17211D);
  static const surfaceHigher = Color(0xFF202C26);
  static const border = Color(0xFF29372F);

  static const textPrimary = Color(0xFFF2F4EC);
  static const textSecondary = Color(0xFFA0ADA5);
  static const textTertiary = Color(0xFF6F7D74);

  static const green = Color(0xFFD0F477);
  static const yellow = Color(0xFFF5CC70);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xFF101713),
      indicatorColor: AppColors.green.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.textTertiary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textTertiary,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigher,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
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
