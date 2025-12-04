import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle display = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 40 / 32,
  );

  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );

  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  );

  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 24 / 18,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 24 / 16,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 20 / 14,
  );

  static TextStyle small = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 16 / 12,
  );
}
