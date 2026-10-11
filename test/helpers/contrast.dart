/// The one place the repo measures colour contrast (WCAG 2.1).
///
/// Test support only: nothing in `lib/` computes contrast. The ratios agree
/// with the colour audit behind design/system/README.md "Contrast" to two
/// decimals.
library;

import 'package:flutter/painting.dart';

/// Minimum for text under 24px (WCAG 1.4.3 AA).
const double kMinText = 4.5;

/// Minimum for borders, focus rings and icons that carry meaning (WCAG 1.4.11).
const double kMinGraphic = 3.0;

/// [fg] painted over the opaque [ground], with the alpha kept as a fraction
/// and each channel rounded half up to 8 bits (the colour audit's method; it
/// is within one level of [Color.alphaBlend]). A translucent [ground] is
/// rejected: compose it over what it sits on first.
Color composeOver(Color fg, Color ground) {
  assert(ground.a == 1, 'The ground must be opaque: compose it first.');
  final a = fg.a;
  // The epsilon makes an exact half (15% of 185 over white is 244.5) round up
  // despite floating-point error.
  int channel(double top, double bottom) =>
      ((top * a + bottom * (1 - a)) * 255 + 0.5 + 1e-9).floor().clamp(0, 255);
  return Color.fromARGB(
    255,
    channel(fg.r, ground.r),
    channel(fg.g, ground.g),
    channel(fg.b, ground.b),
  );
}

/// WCAG contrast ratio of [fg] on the opaque [ground], from 1 to 21. A
/// translucent [fg] is judged over [ground], the way it is painted. A
/// translucent [ground] is rejected.
double contrastRatio(Color fg, Color ground) {
  assert(ground.a == 1, 'The ground must be opaque: compose it first.');
  final a = composeOver(fg, ground).computeLuminance();
  final b = ground.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
