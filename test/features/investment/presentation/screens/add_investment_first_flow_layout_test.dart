// A40 (#783) PR-2, plan test 6: the real flag-on form, not stub slots, laid out
// at the narrowest phone, with large text, the keyboard up and More details
// open. Anything that overflows there is clipped in a release build.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

import '../../../../helpers/inter_font.dart';
import 'add_investment_harness.dart';

final _now = DateTime(2026, 10, 11, 14, 30);

const _keyboard = 250.0;

Future<void> _openMoreDetails(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(AddInvestmentKeys.moreDetails));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More details'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadInterFont);

  for (final (width, height) in [(320.0, 568.0), (360.0, 640.0)]) {
    for (final scale in [1.8, 2.0]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final where = '${width.toInt()}x${height.toInt()}, text $scale, $mode';

        testWidgets('More details does not overflow: $where', (tester) async {
          await pumpAddForm(
            tester,
            flagOn: true,
            now: _now,
            size: Size(width, height),
            textScale: scale,
            themeMode: mode,
            appTheme: true,
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await _openMoreDetails(tester);

          expect(tester.takeException(), isNull);
        });

        testWidgets('the Auto badge beside the maturity label fits: $where', (
          tester,
        ) async {
          await pumpAddForm(
            tester,
            flagOn: true,
            now: _now,
            size: Size(width, height),
            textScale: scale,
            themeMode: mode,
            appTheme: true,
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await _openMoreDetails(tester);

          // A tenure works out a maturity date, which shows the Auto badge.
          final tenure = find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is AppTextField && w.label == 'Tenure (Months)',
            ),
            matching: find.byType(EditableText),
          );
          await tester.ensureVisible(tenure);
          await tester.enterText(tenure, '12');
          await tester.pumpAndSettle();

          expect(find.text('Auto'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
