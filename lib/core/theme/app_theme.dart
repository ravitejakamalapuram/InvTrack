import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

/// App theme configuration.
class AppTheme {
  AppTheme._();

  /// Light theme.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: AppSpacing.borderRadiusSm, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: AppSpacing.borderRadiusSm, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSm,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSm,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 1, space: 0),
      listTileTheme: const ListTileThemeData(contentPadding: AppSpacing.paddingHorizontalLg),
    );
  }

  /// Dark theme.
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      error: AppColors.error,
      surface: AppColors.surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

