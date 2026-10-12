// PR 8, the known hard-coded colours of the contrast series:
//
//  - the compact CurrencyBadge text (row 54),
//  - the GradientButton tail (row 55),
//  - the QuickStatCard label and subtitle (rows 74 and 75).
//
// The ids in the names are rows of test/core/theme/contrast_pairs.dart; the
// guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/currency_badge.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/quick_stat_card.dart';

import '../../helpers/contrast.dart';
import '../../helpers/themed_pump.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Color _page(Brightness b) =>
    b == Brightness.dark ? AppColors.backgroundDark : AppColors.backgroundLight;

Color _glass(Brightness b) => composeOver(
  b == Brightness.dark
      ? AppColors.cardDark.withValues(alpha: 0.8)
      : AppColors.cardLight.withValues(alpha: 0.9),
  _page(b),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('compact CurrencyBadge', () {
    for (final (brightness, id) in [
      (Brightness.light, 'currency-badge-compact-light@tint20'),
      (Brightness.dark, 'currency-badge-compact-dark@tint20'),
    ]) {
      testWidgets('$id: the code reads on its tint', (tester) async {
        await pumpThemed(
          tester,
          const CurrencyBadge(currencyCode: 'EUR', compact: true),
          brightness: brightness,
        );
        final finder = find.text('EUR');
        final color = paintedTextColor(tester, finder);
        final ground = groundBehind(
          tester,
          finder,
          brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.cardLight,
        );
        expect(
          color,
          brightness == Brightness.dark
              ? AppColors.primaryLightDark
              : AppColors.primaryDarkLight,
        );
        expect(
          contrastRatio(color, ground),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
      });
    }
  });

  group('GradientButton', () {
    for (final (brightness, id) in [
      (Brightness.light, 'gradient-button-tail-light@page'),
      (Brightness.dark, 'gradient-button-tail-dark@page'),
    ]) {
      testWidgets(
        '$id: the white label reads over the tail, and the fill is still the '
        'primary colour',
        (tester) async {
          await pumpThemed(
            tester,
            GradientButton(onPressed: () {}, label: 'Save'),
            brightness: brightness,
          );
          final box = tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((d) => d.gradient != null);
          final colors = (box.gradient! as LinearGradient).colors;
          // The fill stays the primary colour in both themes: white on the
          // dark theme's lighter indigo would be 3.33:1.
          expect(colors.first, AppColors.primaryLight);
          final tail = composeOver(colors.last, _page(brightness));
          expect(
            contrastRatio(Colors.white, tail),
            greaterThanOrEqualTo(kMinText),
            reason: id,
          );
          expect(find.text('Save'), findsOneWidget);
        },
      );
    }
  });

  group('GradientButton with a custom colour', () {
    // Add Transaction's Save button is green for money in and red for money
    // out; its label read at 2.46:1 on the dark green.
    for (final (brightness, fill, id) in [
      (Brightness.light, AppColors.successLight, 'success-light'),
      (Brightness.dark, AppColors.successDark, 'success-dark'),
      (Brightness.light, AppColors.errorLight, 'error-light'),
      (Brightness.dark, AppColors.errorDark, 'error-dark'),
    ]) {
      testWidgets('$id: the label reads over the whole gradient', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          GradientButton(onPressed: () {}, label: 'Save', color: fill),
          brightness: brightness,
        );
        final box = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.gradient != null);
        final colors = (box.gradient! as LinearGradient).colors;
        final label = paintedTextColor(tester, find.text('Save'));
        for (final end in colors) {
          expect(
            contrastRatio(label, composeOver(end, _page(brightness))),
            greaterThanOrEqualTo(kMinText),
            reason: id,
          );
        }
      });
    }
  });

  group('QuickStatCard', () {
    for (final (brightness, labelId, subtitleId) in [
      (
        Brightness.light,
        'quick-stat-label-light@card',
        'quick-stat-subtitle-light@card',
      ),
      (
        Brightness.dark,
        'quick-stat-label-dark@card',
        'quick-stat-subtitle-dark@card',
      ),
    ]) {
      testWidgets(
        '$labelId and $subtitleId: the label and the subtitle read on the card',
        (tester) async {
          await pumpThemed(
            tester,
            const QuickStatCard(
              icon: Icons.pie_chart_rounded,
              label: 'Active',
              value: '12',
              color: AppColors.primaryLight,
              subtitle: 'of 15 total',
            ),
            brightness: brightness,
            overrides: [privacyModeProvider.overrideWith(_PrivacyOff.new)],
          );
          final label = paintedTextColor(tester, find.text('Active'));
          final subtitle = paintedTextColor(tester, find.text('of 15 total'));
          final dark = brightness == Brightness.dark;
          expect(
            label,
            dark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          );
          expect(
            subtitle,
            dark ? AppColors.neutral500Dark : AppColors.neutral400Light,
          );
          final ground = _glass(brightness);
          expect(
            contrastRatio(label, ground),
            greaterThanOrEqualTo(kMinText),
            reason: labelId,
          );
          expect(
            contrastRatio(subtitle, ground),
            greaterThanOrEqualTo(kMinText),
            reason: subtitleId,
          );
        },
      );
    }
  });
}
