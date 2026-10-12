// The sample-data banner paints its title and icon in the accent: the deeper
// blue text colour in light, on a banner that stays tinted with the bright blue,
// and the dark blue in dark.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/sample_data_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _SampleModeOn extends SampleDataModeNotifier {
  @override
  SampleDataState build() => const SampleDataState(isActive: true);
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sampleDataModeProvider.overrideWith(_SampleModeOn.new)],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SampleDataBanner()),
      ),
    ),
  );
  await tester.pump();
}

/// The fills (each under half strength) around [target], outermost first,
/// composed over [base].
Color _groundBehind(WidgetTester tester, Finder target, Color base) {
  final tints = <Color>[];
  for (final element
      in find
          .ancestor(of: target, matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration &&
        decoration.color != null &&
        decoration.color!.a < 0.5) {
      tints.add(decoration.color!);
    }
  }
  var ground = base;
  for (final tint in tints.reversed) {
    ground = composeOver(tint, ground);
  }
  return ground;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'sample-data-banner-light@tint10: the title reads on the banner and says '
    'what it is',
    (tester) async {
      await _pump(tester, AppTheme.lightTheme);

      final title = find.text('Sample Data Mode');
      expect(title, findsOneWidget);
      final color = tester.widget<Text>(title).style!.color!;
      expect(color, AppColors.accentTextLight);
      // The banner stays the bright blue at 10% over the page.
      final ground = _groundBehind(tester, title, AppColors.backgroundLight);
      expect(
        ground,
        composeOver(
          AppColors.accentLight.withValues(alpha: 0.1),
          AppColors.backgroundLight,
        ),
      );
      expect(
        contrastRatio(color, ground),
        greaterThanOrEqualTo(kMinText),
        reason: 'sample-data-banner-light@tint10',
      );
    },
  );

  testWidgets('sample-data-icon-light@tint20: the icon reads on its disc', (
    tester,
  ) async {
    await _pump(tester, AppTheme.lightTheme);

    final icon = find.byIcon(Icons.science_rounded);
    final color = tester.widget<Icon>(icon).color!;
    expect(color, AppColors.accentTextLight);
    final ground = _groundBehind(tester, icon, AppColors.backgroundLight);
    expect(
      ground,
      composeOver(
        AppColors.accentLight.withValues(alpha: 0.2),
        composeOver(
          AppColors.accentLight.withValues(alpha: 0.1),
          AppColors.backgroundLight,
        ),
      ),
    );
    expect(
      contrastRatio(color, ground),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'sample-data-icon-light@tint20',
    );
  });

  testWidgets('in dark the title and the icon are the dark blue', (
    tester,
  ) async {
    await _pump(tester, AppTheme.darkTheme);

    expect(
      tester.widget<Text>(find.text('Sample Data Mode')).style!.color,
      AppColors.accentDark,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.science_rounded)).color,
      AppColors.accentDark,
    );
  });
}
