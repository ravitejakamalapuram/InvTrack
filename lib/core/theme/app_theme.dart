import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        primaryContainer: AppColors.primaryLightLight,
        secondary: AppColors.accentLight,
        secondaryContainer: AppColors.accentDarkLight,
        tertiary: AppColors.graphPurple,
        surface: AppColors.whiteLight,
        error: AppColors.dangerLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.neutral900Light,
        onError: Colors.white,
        outline: AppColors.neutral300Light,
        outlineVariant: AppColors.neutral200Light,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.neutral900Light),
        displayMedium: AppTypography.display.copyWith(color: AppColors.neutral900Light),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.neutral900Light),
        headlineLarge: AppTypography.h1.copyWith(color: AppColors.neutral900Light),
        headlineMedium: AppTypography.h2.copyWith(color: AppColors.neutral900Light),
        headlineSmall: AppTypography.h3.copyWith(color: AppColors.neutral900Light),
        titleLarge: AppTypography.h3.copyWith(color: AppColors.neutral900Light),
        titleMedium: AppTypography.h4.copyWith(color: AppColors.neutral900Light),
        bodyLarge: AppTypography.body.copyWith(color: AppColors.neutral900Light),
        bodyMedium: AppTypography.caption.copyWith(color: AppColors.neutral600Light),
        bodySmall: AppTypography.small.copyWith(color: AppColors.neutral500Light),
        labelLarge: AppTypography.label.copyWith(color: AppColors.neutral700Light),
        labelMedium: AppTypography.button.copyWith(color: AppColors.neutral600Light),
        labelSmall: AppTypography.tiny.copyWith(color: AppColors.neutral500Light),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.neutral900Light,
        centerTitle: false,
        titleTextStyle: AppTypography.h2.copyWith(color: AppColors.neutral900Light),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.neutral300Light, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: AppTypography.button,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral100Light,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300Light, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerLight, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppTypography.body.copyWith(color: AppColors.neutral500Light),
        labelStyle: AppTypography.label.copyWith(color: AppColors.neutral600Light),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.whiteLight,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.neutral500Light,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.tiny.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.tiny,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.whiteLight,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.1),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.tiny.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.tiny.copyWith(color: AppColors.neutral500Light);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 24);
          }
          return const IconThemeData(color: AppColors.neutral500Light, size: 24);
        }),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.neutral200Light,
        thickness: 1,
        space: 1,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral100Light,
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.15),
        labelStyle: AppTypography.small,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.surfaceDark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        primaryContainer: AppColors.primaryLightDark,
        secondary: AppColors.accentDark,
        tertiary: AppColors.graphPurple,
        surface: AppColors.cardDark,
        error: AppColors.dangerDark,
        onPrimary: AppColors.neutral950Dark,
        onSecondary: AppColors.neutral950Dark,
        onSurface: AppColors.neutral50Dark,
        onError: Colors.white,
        outline: AppColors.neutral700Dark,
        outlineVariant: AppColors.neutral800Dark,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.neutral50Dark),
        displayMedium: AppTypography.display.copyWith(color: AppColors.neutral50Dark),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.neutral50Dark),
        headlineLarge: AppTypography.h1.copyWith(color: AppColors.neutral50Dark),
        headlineMedium: AppTypography.h2.copyWith(color: AppColors.neutral50Dark),
        headlineSmall: AppTypography.h3.copyWith(color: AppColors.neutral50Dark),
        titleLarge: AppTypography.h3.copyWith(color: AppColors.neutral50Dark),
        titleMedium: AppTypography.h4.copyWith(color: AppColors.neutral50Dark),
        bodyLarge: AppTypography.body.copyWith(color: AppColors.neutral100Dark),
        bodyMedium: AppTypography.caption.copyWith(color: AppColors.neutral400Dark),
        bodySmall: AppTypography.small.copyWith(color: AppColors.neutral500Dark),
        labelLarge: AppTypography.label.copyWith(color: AppColors.neutral100Dark),
        labelMedium: AppTypography.button.copyWith(color: AppColors.neutral400Dark),
        labelSmall: AppTypography.tiny.copyWith(color: AppColors.neutral500Dark),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.neutral50Dark,
        centerTitle: false,
        titleTextStyle: AppTypography.h2.copyWith(color: AppColors.neutral50Dark),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.neutral950Dark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.neutral700Dark, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral800Dark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral700Dark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppTypography.body.copyWith(color: AppColors.neutral500Dark),
        labelStyle: AppTypography.label.copyWith(color: AppColors.neutral400Dark),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.neutral500Dark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.tiny.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.tiny,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        indicatorColor: AppColors.primaryDark.withValues(alpha: 0.2),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.tiny.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.tiny.copyWith(color: AppColors.neutral500Dark);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: AppColors.neutral500Dark, size: 24);
        }),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.neutral950Dark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.neutral800Dark,
        thickness: 1,
        space: 1,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral800Dark,
        selectedColor: AppColors.primaryDark.withValues(alpha: 0.25),
        labelStyle: AppTypography.small.copyWith(color: AppColors.neutral100Dark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
