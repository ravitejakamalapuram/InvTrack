import 'package:flutter/material.dart';

class AppColors {
  // ============================================
  // LIGHT MODE - Premium Finance App Palette (CRED-inspired)
  // ============================================

  // Primary - Deep Indigo with purple undertones
  static const Color primaryLight = Color(0xFF5B4CDB);
  static const Color primaryDarkLight = Color(0xFF4338CA);
  static const Color primaryLightLight = Color(0xFF8B7CF6);

  // Accent - Luxurious Teal/Cyan
  static const Color accentLight = Color(0xFF0EA5E9);
  static const Color accentDarkLight = Color(0xFF0284C7);

  // Success - Emerald Green (premium feel)
  static const Color successLight = Color(0xFF10B981);
  static const Color successBgLight = Color(0xFFD1FAE5);

  // Danger - Coral Red (softer, premium)
  static const Color dangerLight = Color(0xFFEF4444);
  static const Color dangerBgLight = Color(0xFFFEE2E2);

  // Warning - Rich Amber
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningBgLight = Color(0xFFFEF3C7);

  // Neutrals - Warm Gray Scale (more premium than cool gray)
  static const Color neutral950Light = Color(0xFF0C0A09);
  static const Color neutral900Light = Color(0xFF1C1917);
  static const Color textPrimaryLight = neutral900Light;
  static const Color neutral800Light = Color(0xFF292524);
  static const Color neutral700Light = Color(0xFF44403C);
  static const Color neutral600Light = Color(0xFF57534E);
  static const Color neutral500Light = Color(0xFF78716C);
  static const Color neutral400Light = Color(0xFFA8A29E);
  static const Color neutral300Light = Color(0xFFD6D3D1);
  static const Color neutral200Light = Color(0xFFE7E5E4);
  static const Color neutral100Light = Color(0xFFF5F5F4);
  static const Color whiteLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFFAFAF9);

  // Card & Surface - Subtle warmth
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F4);

  // ============================================
  // DARK MODE - CRED-inspired Premium Dark Theme
  // Deep blacks with subtle purple/blue undertones
  // ============================================

  // Primary - Brighter in dark mode for contrast
  static const Color primaryDark = Color(0xFF8B7CF6);
  static const Color primaryLightDark = Color(0xFFA5B4FC);

  // Accent - Vibrant cyan for dark mode
  static const Color accentDark = Color(0xFF38BDF8);

  // Status Colors - Slightly brighter for dark mode
  static const Color successDark = Color(0xFF34D399);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color warningDark = Color(0xFFFBBF24);

  // Error - Alias for danger (commonly used)
  static const Color errorLight = dangerLight;
  static const Color errorDark = dangerDark;

  // Neutrals - Deep blacks with subtle warmth (CRED-like)
  static const Color neutral50Dark = Color(0xFFFAFAF9);
  static const Color neutral100Dark = Color(0xFFF5F5F4);
  static const Color neutral200Dark = Color(0xFFE7E5E4);
  static const Color neutral300Dark = Color(0xFFD6D3D1);
  static const Color neutral400Dark = Color(0xFFA8A29E);
  static const Color neutral500Dark = Color(0xFF78716C);
  static const Color neutral600Dark = Color(0xFF57534E);
  static const Color neutral700Dark = Color(0xFF292524);
  static const Color neutral800Dark = Color(0xFF1C1917);
  static const Color neutral900Dark = Color(0xFF0C0A09);
  static const Color neutral950Dark = Color(0xFF0A0A0A);

  // Text colors - Semantic aliases
  static const Color textPrimaryDark = neutral50Dark;
  static const Color textSecondaryLight = neutral500Light;
  static const Color textSecondaryDark = neutral400Dark;

  // Card & Surface - Deep, rich blacks
  static const Color cardDark = Color(0xFF171717);
  static const Color surfaceDark = Color(0xFF0A0A0A);
  static const Color backgroundDark = Color(0xFF0A0A0A);

  // ============================================
  // GRADIENTS - Premium, CRED-inspired
  // ============================================

  // Primary Gradients - Rich purple to indigo
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B4CDB), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF8B7CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Success Gradient (for positive returns) - Emerald to teal
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Danger Gradient (for negative returns) - Rose to coral
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card Gradient (subtle) - Warm white
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFAF9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Hero Gradient (for main dashboard card) - Premium purple spectrum
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF5B4CDB), Color(0xFF7C3AED), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark mode hero - Deep, rich purples
  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF3B0764)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium gold gradient for special highlights
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle glass gradient for cards
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark glass gradient
  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [Color(0x1A000000), Color(0x0D000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================
  // GRAPH/CHART COLORS - Vibrant & Distinct
  // ============================================
  static const Color graphIndigo = Color(0xFF4F46E5);
  static const Color graphBlue = Color(0xFF3B82F6);
  static const Color graphCyan = Color(0xFF06B6D4);
  static const Color graphTeal = Color(0xFF14B8A6);
  static const Color graphEmerald = Color(0xFF10B981);
  static const Color graphLime = Color(0xFF84CC16);
  static const Color graphAmber = Color(0xFFF59E0B);
  static const Color graphOrange = Color(0xFFF97316);
  static const Color graphRose = Color(0xFFF43F5E);
  static const Color graphPink = Color(0xFFEC4899);
  static const Color graphPurple = Color(0xFFA855F7);
  static const Color graphViolet = Color(0xFF8B5CF6);

  // Chart color palette (for pie charts, etc.)
  static const List<Color> chartPalette = [
    graphIndigo,
    graphTeal,
    graphAmber,
    graphRose,
    graphCyan,
    graphPurple,
    graphEmerald,
    graphOrange,
    graphPink,
    graphBlue,
    graphViolet,
    graphLime,
  ];

  // ============================================
  // SHADOWS
  // ============================================
  static List<BoxShadow> get cardShadowLight => [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadowDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get primaryButtonShadow => [
    BoxShadow(
      color: primaryLight.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
