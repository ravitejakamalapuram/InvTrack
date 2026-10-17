import 'package:flutter/material.dart';

class AppColors {
  // ============================================
  // LIGHT MODE - Premium Finance App Palette (CRED-inspired)
  // ============================================

  // Primary - Deep Indigo with purple undertones
  static const Color primaryLight = Color(0xFF5B4CDB);
  static const Color primaryDarkLight = Color(0xFF4338CA);
  static const Color primaryLightLight = Color(0xFF8B7CF6);

  // Accent - Luxurious Teal/Cyan. The bright blue is for fills, tints, borders
  // and gradients; as text it is 2.77:1 on the card.
  static const Color accentLight = Color(0xFF0EA5E9);
  static const Color accentDarkLight = Color(0xFF0284C7);

  // The deeper blue for text and icons on the card, the page or a tint of
  // `accentLight`: 5.50:1 on the card, 4.75:1 on a 15% tint of `accentLight`
  // over it, 4.58:1 on a 10% tint of the primary indigo over the page. Never a
  // fill, and never the source of a tint: a 15% tint of this blue puts its own
  // label at 4.45:1. Light only; dark reads `accentDark`.
  static const Color accentTextLight = Color(0xFF00709F);

  // Success - Emerald Green (premium feel). Deep enough to read as text:
  // 5.37:1 on the card, 4.73:1 on `successBgLight`, 5.37:1 under a white label.
  static const Color successLight = Color(0xFF007A54);
  static const Color successBgLight = Color(0xFFD1FAE5);

  // Danger - Coral Red (softer, premium). 5.62:1 on the card, 4.60:1 on
  // `dangerBgLight`, 5.62:1 under a white label.
  static const Color dangerLight = Color(0xFFCC1926);
  static const Color dangerBgLight = Color(0xFFFEE2E2);

  // Tint sources: the brighter hues that `successLight` and `dangerLight` had
  // before they were deepened for text. Make every 10 to 30% tint of green or
  // red from these, so the pale fills keep their look and the text on them
  // keeps 4.5:1 (on a tint of the deeper colour it falls to 4.34 and 4.38 at
  // 15%). Never paint them as text.
  //
  // Text reaches 4.5:1 on a 15% tint only over the card (4.67 and 4.63); over
  // the page it is 4.48 and 4.45 and over `surfaceLight` 4.31 and 4.25. A 15%
  // chip belongs inside a GlassCard; on the page or a sheet use 10%.
  //
  // A scan test (theme_aware_sites_test.dart) fails a bare read of these and a
  // direct `.withValues` on the deeper colours. It does not see a colour held
  // in a variable, an alias, a `Color.lerp` or a hex copy: those tints are
  // split by hand and a widget test pumps each one.
  static const Color successTintLight = Color(0xFF10B981);
  static const Color dangerTintLight = Color(0xFFEF4444);

  // Warning - Rich Amber. The bright amber is for fills, tints, borders and
  // gradients; as text it is 2.15:1 on the card.
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningBgLight = Color(0xFFFEF3C7);

  // The deeper amber for text and icons on the card or a tint of
  // `warningLight`: 5.21:1 on the card, 4.64:1 on a 15% tint of `warningLight`
  // over it, 4.68:1 on `warningBgLight`. Never a fill, and never the source of
  // a tint: a 15% tint of this amber puts its own label at 4.25:1. Light only;
  // dark reads `warningDark`.
  static const Color warningTextLight = Color(0xFF996000);

  // The word CLOSED on the investment card's grey chip (a 20% tint of
  // `Colors.grey` over the card): 4.65:1 in this grey, 2.27:1 in `Colors.grey`
  // itself. Light only; in dark `Colors.grey` is the readable one.
  static const Color closedTextLight = Color(0xFF696969);

  /// The colour for a label or an icon painted on [fill]: white or
  /// [neutral900Light] (ink), whichever has the higher contrast ratio on it.
  /// One rule for the selected type chip, the type tile and the detail header,
  /// where a luminance threshold used to put white on gold (1.40:1).
  ///
  /// [fill] must be opaque. A fill whose luminance is near 0.2 reaches at most
  /// 4.16:1 with either colour; such a fill is changed, not labelled (the
  /// purple of crypto and private equity was).
  static Color onFill(Color fill) {
    final luminance = fill.computeLuminance();
    final white = 1.05 / (luminance + 0.05);
    final ink =
        (luminance + 0.05) / (neutral900Light.computeLuminance() + 0.05);
    return white >= ink ? Colors.white : neutral900Light;
  }

  // Neutrals - Warm Gray Scale (more premium than cool gray)
  static const Color neutral950Light = Color(0xFF0C0A09);
  static const Color neutral900Light = Color(0xFF1C1917);
  static const Color textPrimaryLight = neutral900Light;
  static const Color neutral800Light = Color(0xFF292524);
  static const Color neutral700Light = Color(0xFF44403C);
  static const Color neutral600Light = Color(0xFF57534E);
  // Muted and subtle text: 4.5:1 or more on the card, page and surface.
  static const Color neutral500Light = Color(0xFF66615C);
  static const Color neutral400Light = Color(0xFF746E6A);
  static const Color neutral300Light = Color(0xFFD6D3D1);
  static const Color neutral200Light = Color(0xFFE7E5E4);
  // Input and button outlines: 3:1 or more on the page, card, surface and input fill.
  static const Color fieldBorderLight = Color(0xFF8D8B8A);
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
  // Muted text and hints: 4.5:1 or more on the page, card and input fill.
  static const Color neutral500Dark = Color(0xFF89827C);
  static const Color neutral600Dark = Color(0xFF57534E);
  static const Color neutral700Dark = Color(0xFF292524);
  // Input and button outlines: 3:1 or more on the page, card and input fill.
  static const Color fieldBorderDark = Color(0xFF6B6765);
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

  // Archive Gradient (for archive actions) - Amber to orange
  static const LinearGradient archiveGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
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

  // Text on the hero gradient: white at 90% reads on every stop of both
  // gradients (4.65:1 at the lightest, #9333ea). One step for all secondary
  // text, so the hierarchy comes from size and weight, not from fading.
  static const Color heroSecondaryText = Color(0xE6FFFFFF);

  // The fill under the hero's toggle and return badge: black at 20% darkens
  // the gradient so white text on it clears 4.5:1 on every stop.
  static const Color heroChipFill = Color(0x33000000);

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

  // Deeper cyan and purple for text on a light card (4.64:1 and 4.62:1). The
  // chart fills and the dark theme keep graphCyan and graphPurple; emerald text
  // in light uses successLight.
  static const Color graphCyanLight = Color(0xFF008096);
  static const Color graphPurpleLight = Color(0xFF9D48EA);
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
