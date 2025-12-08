import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // ============================================
  // DISPLAY - Hero text, large headlines
  // ============================================
  static TextStyle displayLarge = GoogleFonts.plusJakartaSans(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.5,
  );

  static TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -1,
  );

  static TextStyle displaySmall = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );

  // ============================================
  // HEADINGS - Section titles
  // ============================================
  static TextStyle h1 = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static TextStyle h2 = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static TextStyle h3 = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle h4 = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ============================================
  // BODY - Main content text
  // ============================================
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  // ============================================
  // LABELS & CAPTIONS
  // ============================================
  static TextStyle label = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle small = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle tiny = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // ============================================
  // SPECIAL - Numbers, metrics, etc.
  // ============================================
  static TextStyle numberLarge = GoogleFonts.plusJakartaSans(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1,
  );

  static TextStyle number = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle numberSmall = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle percentage = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ============================================
  // BUTTONS
  // ============================================
  static TextStyle buttonLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle button = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );
}
