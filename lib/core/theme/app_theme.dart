import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.neutral100Light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        secondary: AppColors.primaryDarkLight,
        surface: AppColors.whiteLight,
        error: AppColors.dangerLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.neutral900Light,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(color: AppColors.neutral900Light),
        headlineLarge: AppTypography.h1.copyWith(color: AppColors.neutral900Light),
        headlineMedium: AppTypography.h2.copyWith(color: AppColors.neutral900Light),
        headlineSmall: AppTypography.h3.copyWith(color: AppColors.neutral900Light),
        bodyLarge: AppTypography.body.copyWith(color: AppColors.neutral900Light),
        bodyMedium: AppTypography.caption.copyWith(color: AppColors.neutral600Light),
        bodySmall: AppTypography.small.copyWith(color: AppColors.neutral400Light),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.whiteLight,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.neutral900Dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.primaryDark,
        surface: AppColors.neutral800Dark,
        error: AppColors.dangerDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.neutral50Dark,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(color: AppColors.neutral50Dark),
        headlineLarge: AppTypography.h1.copyWith(color: AppColors.neutral50Dark),
        headlineMedium: AppTypography.h2.copyWith(color: AppColors.neutral50Dark),
        headlineSmall: AppTypography.h3.copyWith(color: AppColors.neutral50Dark),
        bodyLarge: AppTypography.body.copyWith(color: AppColors.neutral50Dark),
        bodyMedium: AppTypography.caption.copyWith(color: AppColors.neutral400Dark),
        bodySmall: AppTypography.small.copyWith(color: AppColors.neutral400Dark),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.neutral800Dark,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
