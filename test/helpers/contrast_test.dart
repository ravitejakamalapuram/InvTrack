// The contrast helper must agree with the audit's printed ratios, because the
// guard in test/core/theme/contrast_guard_test.dart is only as good as it.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast.dart';

void main() {
  group('contrastRatio', () {
    const white = Color(0xFFFFFFFF);

    // Ratios the audit printed (two decimals). The first four are the
    // failing pairs that PRs 4 and 5 fix.
    final cases = <(String, Color, Color, double)>[
      ('#10b981 on white', const Color(0xFF10B981), white, 2.54),
      (
        '#78716c on #f5f5f4',
        const Color(0xFF78716C),
        const Color(0xFFF5F5F4),
        4.40,
      ),
      ('#a8a29e on white', const Color(0xFFA8A29E), white, 2.52),
      (
        '#ef4444 on #fee2e2',
        const Color(0xFFEF4444),
        const Color(0xFFFEE2E2),
        3.08,
      ),
      (
        '#8b7cf6 on #171717',
        const Color(0xFF8B7CF6),
        const Color(0xFF171717),
        5.39,
      ),
    ];
    for (final (name, fg, ground, expected) in cases) {
      test(name, () {
        expect(contrastRatio(fg, ground), closeTo(expected, 0.005));
      });
    }

    test('white on black is exactly 21', () {
      expect(
        contrastRatio(white, const Color(0xFF000000)),
        closeTo(21.0, 1e-9),
      );
    });

    test('black on black is exactly 1', () {
      const black = Color(0xFF000000);
      expect(contrastRatio(black, black), closeTo(1.0, 1e-9));
    });

    test('is symmetric for opaque colours', () {
      const a = Color(0xFF5B4CDB);
      const b = Color(0xFFFAFAF9);
      expect(contrastRatio(a, b), contrastRatio(b, a));
    });

    test('a translucent foreground is judged over the ground', () {
      // Row 58 of the audit: white at 90% on the hero stop #7c3aed is 4.91.
      expect(
        contrastRatio(white.withValues(alpha: 0.9), const Color(0xFF7C3AED)),
        closeTo(4.91, 0.005),
      );
    });
  });

  group('composeOver', () {
    test('keeps an opaque foreground', () {
      const fg = Color(0xFF10B981);
      expect(composeOver(fg, const Color(0xFFFFFFFF)), fg);
    });

    test('rounds each channel to 8 bits like the audit', () {
      // Rows 00 and 11 of the audit: 15% tints over a white card.
      expect(
        composeOver(
          const Color(0xFF0EA5E9).withValues(alpha: 0.15),
          const Color(0xFFFFFFFF),
        ),
        const Color(0xFFDBF2FC),
      );
      expect(
        composeOver(
          const Color(0xFF10B981).withValues(alpha: 0.15),
          const Color(0xFFFFFFFF),
        ),
        const Color(0xFFDBF5EC),
      );
    });

    test('is within one level of the engine blend for every alpha in use', () {
      const fg = Color(0xFF7C3AED);
      const ground = Color(0xFF171717);
      for (final alpha in [0.03, 0.05, 0.08, 0.1, 0.15, 0.2, 0.3, 0.7, 0.9]) {
        final ours = composeOver(fg.withValues(alpha: alpha), ground);
        final engine = Color.alphaBlend(fg.withValues(alpha: alpha), ground);
        expect((ours.r - engine.r).abs() * 255, lessThanOrEqualTo(1.0001));
        expect((ours.g - engine.g).abs() * 255, lessThanOrEqualTo(1.0001));
        expect((ours.b - engine.b).abs() * 255, lessThanOrEqualTo(1.0001));
      }
    });

    test('fully transparent shows the ground', () {
      const ground = Color(0xFF171717);
      expect(composeOver(const Color(0x00FFFFFF), ground), ground);
    });
  });

  test('minimums are the WCAG 2.1 AA levels', () {
    expect(kMinText, 4.5);
    expect(kMinGraphic, 3.0);
  });
}
