// The empty Overview paints blue and amber icons and text: the Import CSV
// tile, the sample-data tile and its "Try it" button, and the highlighted
// figure of the XIRR demo. In light they take the deeper blue and amber text
// colours; the tiles keep their bright tint. In dark they read the dark values.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: OverviewEmptyState(onImportCsv: () {}, onTrySampleData: () {}),
        ),
      ),
    ),
  );
  // Let the advertised-to-real animation finish.
  await tester.pumpAndSettle();
}

Color _icon(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color!;

/// What is painted behind [target]: every tint (a fill under half strength) of
/// the Containers around it, outermost first, over [base]. The card's own,
/// nearly opaque fill is [base].
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

  group('in light', () {
    testWidgets(
      'quick-start-csv-icon-light@tint20: the Import CSV icon reads on its disc',
      (tester) async {
        await _pump(tester, AppTheme.lightTheme);

        final icon = find.byIcon(Icons.upload_file_rounded);
        expect(
          _icon(tester, Icons.upload_file_rounded),
          AppColors.accentTextLight,
        );
        // The tile and its disc stay the bright blue: a 10% tile, a 20% disc.
        final ground = _groundBehind(tester, icon, AppColors.cardLight);
        expect(
          ground,
          composeOver(
            AppColors.accentLight.withValues(alpha: 0.2),
            composeOver(
              AppColors.accentLight.withValues(alpha: 0.1),
              AppColors.cardLight,
            ),
          ),
        );
        expect(
          contrastRatio(AppColors.accentTextLight, ground),
          greaterThanOrEqualTo(kMinGraphic),
          reason: 'quick-start-csv-icon-light@tint20',
        );
        // The tile says what it is in words.
        expect(find.text('Import CSV'), findsOneWidget);
      },
    );

    testWidgets(
      'sample-data-tile-icon-light@tint20 and sample-data-try-it-light@gradient: '
      'the sample-data tile reads',
      (tester) async {
        await _pump(tester, AppTheme.lightTheme);

        // The icon on its 20% disc, over the tile's gradient.
        expect(_icon(tester, Icons.science_rounded), AppColors.accentTextLight);
        final accentEnd = composeOver(
          AppColors.accentLight.withValues(alpha: 0.1),
          AppColors.backgroundLight,
        );
        final primaryEnd = composeOver(
          AppColors.primaryLight.withValues(alpha: 0.1),
          AppColors.backgroundLight,
        );
        final disc = _groundBehind(
          tester,
          find.byIcon(Icons.science_rounded),
          accentEnd,
        );
        expect(
          contrastRatio(AppColors.accentTextLight, disc),
          greaterThanOrEqualTo(kMinGraphic),
          reason: 'sample-data-tile-icon-light@tint20',
        );

        // The "Try it" button sits toward the primary end of a gradient of two
        // 10% tints over the page: read it on both ends.
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Try It'),
        );
        final color = button.style!.foregroundColor!.resolve({})!;
        expect(color, AppColors.accentTextLight);
        for (final end in [accentEnd, primaryEnd]) {
          expect(
            contrastRatio(color, end),
            greaterThanOrEqualTo(kMinText),
            reason: 'sample-data-try-it-light@gradient',
          );
        }
        // The tint behind the tile is still the bright blue.
        final gradient = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<LinearGradient>()
            .where(
              (g) => g.colors.contains(
                AppColors.accentLight.withValues(alpha: 0.1),
              ),
            );
        expect(gradient, hasLength(1));
      },
    );

    testWidgets(
      'xirr-demo-highlight-light@tint5: the real XIRR is amber and reads, and '
      'says what it is',
      (tester) async {
        await _pump(tester, AppTheme.lightTheme);

        final figure = find.text('6.3%');
        expect(figure, findsOneWidget);
        final color = tester.widget<Text>(figure).style!.color!;
        expect(color, AppColors.warningTextLight);
        expect(_icon(tester, Icons.trending_down_rounded), color);
        // A 5% black veil over the card.
        final ground = _groundBehind(tester, figure, AppColors.cardLight);
        expect(
          ground,
          composeOver(
            Colors.black.withValues(alpha: 0.05),
            AppColors.cardLight,
          ),
        );
        expect(
          contrastRatio(color, ground),
          greaterThanOrEqualTo(kMinText),
          reason: 'xirr-demo-highlight-light@tint5',
        );
        // Colour is not the only carrier: the column is labelled.
        expect(find.text('Your XIRR'), findsOneWidget);
      },
    );
  });

  group('in dark', () {
    testWidgets('the icons, the button and the figure use the dark values', (
      tester,
    ) async {
      await _pump(tester, AppTheme.darkTheme);

      expect(_icon(tester, Icons.upload_file_rounded), AppColors.accentDark);
      expect(_icon(tester, Icons.science_rounded), AppColors.accentDark);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Try It'),
      );
      expect(button.style!.foregroundColor!.resolve({}), AppColors.accentDark);
      expect(
        tester.widget<Text>(find.text('6.3%')).style!.color,
        AppColors.warningDark,
      );
      expect(_icon(tester, Icons.trending_down_rounded), AppColors.warningDark);
    });
  });
}
