// The "Copied" snackbar that CompactAmountText shows paints the colours of the
// theme it is in. Its label takes the theme's snackbar text colour, which is
// white in light and near-black in dark, so the fill has to follow the theme:
// the dark label is only readable on the dark success colour. A fill that stays
// the light success colour in dark loses its label as soon as that colour
// deepens (the gain and loss PR).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../helpers/contrast.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

/// Long-presses the amount, taps the copy button and returns the snackbar that
/// confirms the copy.
Future<SnackBar> _copied(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: CompactAmountText(
              amount: 150000,
              compactText: '₹1.5L',
              currencySymbol: '₹',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.longPress(find.byType(CompactAmountText));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Copy amount'));
  await tester.pumpAndSettle();
  return tester.widget<SnackBar>(find.byType(SnackBar));
}

/// The colour the label is painted in: the snackbar's text style, since the
/// label sets none of its own.
Color _labelColor(WidgetTester tester) {
  final label = find.descendant(
    of: find.byType(SnackBar),
    matching: find.text('Copied to clipboard'),
  );
  expect(label, findsOneWidget);
  return DefaultTextStyle.of(tester.element(label)).style.color!;
}

Color _iconColor(WidgetTester tester) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.check),
      ),
    )
    .color!;

void main() {
  // The theme builds text styles from fonts that are not bundled for tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the Copied snackbar in light', () {
    testWidgets('keeps the light success fill and the white icon', (
      tester,
    ) async {
      final bar = await _copied(tester, AppTheme.lightTheme);
      expect(bar.backgroundColor, AppColors.successLight);
      expect(_iconColor(tester), Colors.white);
    });

    testWidgets(
      'copied-snackbar-label-light: the label and icon read on the deeper green',
      (tester) async {
        final bar = await _copied(tester, AppTheme.lightTheme);
        final fill = bar.backgroundColor!;
        expect(
          contrastRatio(_labelColor(tester), fill),
          greaterThanOrEqualTo(kMinText),
          reason: 'copied-snackbar-label-light',
        );
        expect(
          contrastRatio(_iconColor(tester), fill),
          greaterThanOrEqualTo(kMinGraphic),
          reason: 'the check icon on the fill',
        );
      },
    );
  });

  group('the Copied snackbar in dark', () {
    testWidgets('has the dark success fill', (tester) async {
      final bar = await _copied(tester, AppTheme.darkTheme);
      expect(bar.backgroundColor, AppColors.successDark);
    });

    testWidgets('label and icon reach their minimum on the fill', (
      tester,
    ) async {
      final bar = await _copied(tester, AppTheme.darkTheme);
      final fill = bar.backgroundColor!;
      expect(
        contrastRatio(_labelColor(tester), fill),
        greaterThanOrEqualTo(kMinText),
        reason: 'the label on the fill',
      );
      expect(
        contrastRatio(_iconColor(tester), fill),
        greaterThanOrEqualTo(kMinGraphic),
        reason: 'the check icon on the fill',
      );
    });

    testWidgets('the check icon is the label colour', (tester) async {
      await _copied(tester, AppTheme.darkTheme);
      expect(_iconColor(tester), _labelColor(tester));
    });
  });
}
