// A ChangeBadge for a change of exactly zero paints its text in a grey on a
// grey fill. The text must read on that fill, and a gain or a loss must still
// say which it is without colour: the sign, or the arrow, stays.
//
// The id in the first test name is a row of test/core/theme/contrast_pairs.dart;
// the guard finds it here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/widgets/change_badge.dart';

import '../../helpers/contrast.dart';

Future<void> _pump(WidgetTester tester, double value) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: ChangeBadge(value: value)),
  ),
);

Future<void> _pumpOn(
  WidgetTester tester,
  ThemeData theme, {
  required bool filled,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(body: ChangeBadge(value: 0, filled: filled)),
  ),
);

/// The colour the badge paints behind its text.
Color _fill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(ChangeBadge),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

void main() {
  // The badge builds text styles from fonts that are not bundled for tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'zero-badge-text-light@fill: the zero text reads on its fill and is neutral600Light',
    (tester) async {
      await _pump(tester, 0);
      final text = _textColor(tester, '0.00%');
      final fill = _fill(tester);
      expect(fill, AppColors.neutral200Light);
      expect(
        contrastRatio(text, fill),
        greaterThanOrEqualTo(kMinText),
        reason: 'zero-badge-text-light@fill',
      );
      // The darker grey keeps a margin of more than a point over the minimum;
      // neutral500Light on this fill would sit 0.4 above it.
      expect(text, AppColors.neutral600Light);
      expect(contrastRatio(text, fill), closeTo(6.08, 0.01));
    },
  );

  // The outlined badge has no fill: its text sits on the page. The light grey
  // that is right on the pale fill is too dark there in the dark theme.
  testWidgets(
    'an outlined zero badge reads on the dark page and the dark card',
    (tester) async {
      await _pumpOn(tester, AppTheme.darkTheme, filled: false);
      final text = _textColor(tester, '0.00%');
      expect(text, AppColors.neutral500Dark);
      for (final ground in [AppColors.surfaceDark, AppColors.cardDark]) {
        expect(
          contrastRatio(text, ground),
          greaterThanOrEqualTo(kMinText),
          reason: 'outlined zero badge text on ${ground.toARGB32()}',
        );
      }
    },
  );

  testWidgets('an outlined zero badge reads on the light page', (tester) async {
    await _pumpOn(tester, AppTheme.lightTheme, filled: false);
    final text = _textColor(tester, '0.00%');
    expect(text, AppColors.neutral600Light);
    for (final ground in [AppColors.backgroundLight, AppColors.cardLight]) {
      expect(
        contrastRatio(text, ground),
        greaterThanOrEqualTo(kMinText),
        reason: 'outlined zero badge text on ${ground.toARGB32()}',
      );
    }
  });

  testWidgets('a filled zero badge keeps its pale fill and text in dark', (
    tester,
  ) async {
    await _pumpOn(tester, AppTheme.darkTheme, filled: true);
    final text = _textColor(tester, '0.00%');
    final fill = _fill(tester);
    expect(fill, AppColors.neutral200Light);
    expect(text, AppColors.neutral600Light);
    expect(contrastRatio(text, fill), greaterThanOrEqualTo(kMinText));
  });

  testWidgets('a zero change shows no sign and no arrow', (tester) async {
    await _pump(tester, 0);
    expect(find.text('0.00%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });

  testWidgets('a gain and a loss still carry a sign and an arrow', (
    tester,
  ) async {
    await _pump(tester, 1.5);
    expect(find.text('+1.50%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    await _pump(tester, -1.5);
    expect(find.text('-1.50%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });
}
