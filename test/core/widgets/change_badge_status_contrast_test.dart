// A ChangeBadge paints a gain in the green and a loss in the red. Filled, the
// text sits on a pale green or red; outlined, it sits on the page, which in
// dark is near-black, where the deeper light-theme colours would read about
// 3.3:1. Each is pumped and measured on the ground it sits on. The sign and
// the arrow stay, so colour is not the only carrier.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/widgets/change_badge.dart';

import '../../helpers/contrast.dart';

Future<void> _pumpOn(
  WidgetTester tester,
  ThemeData theme,
  double value, {
  required bool filled,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: ChangeBadge(value: value, filled: filled),
    ),
  ),
);

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

Color _fill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(ChangeBadge),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('a filled badge in light', () {
    testWidgets('success-light@success-bg: a gain reads on the pale green', (
      tester,
    ) async {
      await _pumpOn(tester, AppTheme.lightTheme, 1.5, filled: true);
      expect(_fill(tester), AppColors.successBgLight);
      expect(_textColor(tester, '+1.50%'), AppColors.successLight);
      expect(
        contrastRatio(_textColor(tester, '+1.50%'), _fill(tester)),
        greaterThanOrEqualTo(kMinText),
        reason: 'success-light@success-bg',
      );
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('danger-light@danger-bg: a loss reads on the pale red', (
      tester,
    ) async {
      await _pumpOn(tester, AppTheme.lightTheme, -1.5, filled: true);
      expect(_fill(tester), AppColors.dangerBgLight);
      expect(_textColor(tester, '-1.50%'), AppColors.dangerLight);
      expect(
        contrastRatio(_textColor(tester, '-1.50%'), _fill(tester)),
        greaterThanOrEqualTo(kMinText),
        reason: 'danger-light@danger-bg',
      );
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });
  });

  group('an outlined badge in dark', () {
    for (final (value, text, light, dark, id) in [
      (
        1.5,
        '+1.50%',
        AppColors.successLight,
        AppColors.successDark,
        'change-badge-outlined-success-dark@page',
      ),
      (
        -1.5,
        '-1.50%',
        AppColors.dangerLight,
        AppColors.dangerDark,
        'change-badge-outlined-danger-dark@page',
      ),
    ]) {
      testWidgets('$text reads on the dark page and the dark card ($id)', (
        tester,
      ) async {
        await _pumpOn(tester, AppTheme.darkTheme, value, filled: false);
        final color = _textColor(tester, text);
        // The deeper light colour would be 3.5:1 on the dark page.
        expect(color, isNot(light));
        expect(color, dark);
        for (final ground in [AppColors.backgroundDark, AppColors.cardDark]) {
          expect(
            contrastRatio(color, ground),
            greaterThanOrEqualTo(kMinText),
            reason: id,
          );
        }
      });

      testWidgets('$text in light keeps the light colour', (tester) async {
        await _pumpOn(tester, AppTheme.lightTheme, value, filled: false);
        expect(_textColor(tester, text), light);
        for (final ground in [AppColors.backgroundLight, AppColors.cardLight]) {
          expect(
            contrastRatio(light, ground),
            greaterThanOrEqualTo(kMinText),
            reason: 'outlined badge on ${ground.toARGB32()}',
          );
        }
      });
    }
  });
}
