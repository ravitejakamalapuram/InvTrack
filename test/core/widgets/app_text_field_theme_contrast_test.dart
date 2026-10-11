// AppTextField paints the colours of the theme it is in. In dark, the focus
// ring and the error outline must be the dark values: the light ones are a
// shade too dim on the dark card, and the contrast PRs make them dimmer.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../helpers/contrast.dart';

Future<TextField> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Form(
          autovalidateMode: AutovalidateMode.always,
          child: AppTextField(
            label: 'Name',
            hint: 'Enter a name',
            validator: (_) => 'Name is required',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.widget<TextField>(find.byType(TextField));
}

Color _color(InputBorder? border) =>
    (border! as OutlineInputBorder).borderSide.color;

void main() {
  // The theme builds text styles from fonts that are not bundled for tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('in dark', () {
    testWidgets(
      'primary-focus-border-dark@card: the focus ring is primaryDark',
      (tester) async {
        final field = await _pump(tester, AppTheme.darkTheme);
        final ring = _color(field.decoration!.focusedBorder);
        expect(ring, AppColors.primaryDark);
        expect(
          contrastRatio(ring, AppColors.cardDark),
          closeTo(5.39, 0.01),
          reason: 'primary-focus-border-dark@card',
        );
        expect(
          contrastRatio(ring, AppColors.backgroundDark),
          greaterThanOrEqualTo(kMinGraphic),
        );
      },
    );

    testWidgets('the error outline and its focused form are errorDark', (
      tester,
    ) async {
      final field = await _pump(tester, AppTheme.darkTheme);
      for (final border in [
        field.decoration!.errorBorder,
        field.decoration!.focusedErrorBorder,
      ]) {
        expect(_color(border), AppColors.errorDark);
        expect(
          contrastRatio(_color(border), AppColors.cardDark),
          greaterThanOrEqualTo(kMinGraphic),
        );
      }
    });

    testWidgets('the error message is errorDark, on the field fill', (
      tester,
    ) async {
      await _pump(tester, AppTheme.darkTheme);
      final message = tester.widget<Text>(find.text('Name is required'));
      expect(message.style!.color, AppColors.errorDark);
      expect(
        contrastRatio(message.style!.color!, AppColors.surfaceDark),
        greaterThanOrEqualTo(kMinText),
      );
    });
  });

  group('in light', () {
    testWidgets('the focus ring stays primaryLight', (tester) async {
      final field = await _pump(tester, AppTheme.lightTheme);
      expect(_color(field.decoration!.focusedBorder), AppColors.primaryLight);
    });

    testWidgets('the error outline stays errorLight', (tester) async {
      final field = await _pump(tester, AppTheme.lightTheme);
      expect(_color(field.decoration!.errorBorder), AppColors.errorLight);
      expect(
        _color(field.decoration!.focusedErrorBorder),
        AppColors.errorLight,
      );
    });
  });

  group('the hint', () {
    // The hint is the faintest text grey, so it must read on the fill the field
    // paints: surface in light, the page colour in dark.
    testWidgets('neutral400-light@surface: the light hint reads on the fill', (
      tester,
    ) async {
      final field = await _pump(tester, AppTheme.lightTheme);
      final hint = field.decoration!.hintStyle!.color!;
      final fill = field.decoration!.fillColor!;
      expect(hint, AppColors.neutral400Light);
      expect(fill, AppColors.surfaceLight);
      expect(
        contrastRatio(hint, fill),
        greaterThanOrEqualTo(kMinText),
        reason: 'neutral400-light@surface',
      );
    });

    testWidgets('neutral500-dark@background: the dark hint reads on the fill', (
      tester,
    ) async {
      final field = await _pump(tester, AppTheme.darkTheme);
      final hint = field.decoration!.hintStyle!.color!;
      final fill = field.decoration!.fillColor!;
      expect(hint, AppColors.neutral500Dark);
      expect(fill, AppColors.surfaceDark);
      expect(
        contrastRatio(hint, fill),
        greaterThanOrEqualTo(kMinText),
        reason: 'neutral500-dark@background',
      );
    });
  });
}
