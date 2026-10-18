import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0B0B0E);
  static const surface = Color(0xFF141419);
  static const surfaceHigh = Color(0xFF1A1A21);
  static const surfaceHigher = Color(0xFF22222B);
  static const border = Color(0xFF26262F);

  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFF9C9CA7);
  static const textTertiary = Color(0xFF6C6C78);

  static const green = Color(0xFF3EDC8B);
  static const yellow = Color(0xFFFFC94D);
  static const red = Color(0xFFFF5A5F);

  static const recovery = Color(0xFF3EDC8B);
  static const sleep = Color(0xFF7C8CFF);
  static const strain = Color(0xFFFF6B57);
  static const stress = Color(0xFFFFC94D);
  static const energy = Color(0xFF35D6C4);
  static const nutrition = Color(0xFF9BE15D);
}

ThemeData buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.green,
    onPrimary: Color(0xFF06210F),
    secondary: AppColors.sleep,
    onSecondary: Color(0xFF0B1030),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.red,
    onError: Colors.white,
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
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: const Color(0xFF0E0E12),
      indicatorColor: Colors.white.withValues(alpha: 0.08),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textTertiary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
