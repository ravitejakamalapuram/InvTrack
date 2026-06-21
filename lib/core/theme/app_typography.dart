import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // ============================================
  // DISPLAY - Hero text, large headlines
  // ============================================
  static TextStyle displayLarge = _safeGoogleFont(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.5,
  );

  static TextStyle display = _safeGoogleFont(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -1,
  );

  static TextStyle displaySmall = _safeGoogleFont(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );

  // ============================================
  // HEADINGS - Section titles
  // ============================================
  static TextStyle h1 = _safeGoogleFont(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static TextStyle h2 = _safeGoogleFont(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static TextStyle h3 = _safeGoogleFont(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle h4 = _safeGoogleFont(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ============================================
  // BODY - Main content text
  // ============================================
  static TextStyle bodyLarge = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle body = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodyMedium = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  // ============================================
  // LABELS & CAPTIONS
  // ============================================
  static TextStyle label = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static TextStyle caption = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle small = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle tiny = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // ============================================
  // SPECIAL - Numbers, metrics, etc.
  // ============================================
  static TextStyle numberLarge = _safeGoogleFont(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1,
  );

  static TextStyle number = _safeGoogleFont(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle numberSmall = _safeGoogleFont(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle percentage = _safeGoogleFont(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ============================================
  // BUTTONS
  // ============================================
  static TextStyle buttonLarge = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle button = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle buttonSmall = _safeGoogleFont(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  // ============================================
  // PRIVATE HELPER
  // ============================================
  /// Safe wrapper for GoogleFonts that falls back to bundled fonts if network fails
  ///
  /// Fixes crash: "Exception: Failed to load font with url: https://fonts.gstatic.com/..."
  /// Crashlytics issue: db8b8ac28264602be9b88d553f00969d
  static TextStyle _safeGoogleFont({
    String fontFamily = 'Plus Jakarta Sans',
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    try {
      // Try to load from Google Fonts
      if (fontFamily == 'Inter') {
        return GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      } else {
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      }
    } catch (e) {
      // Fallback to bundled fonts (assets/fonts/) if Google Fonts fails
      // This handles network errors, timeouts, and offline scenarios
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }
}
