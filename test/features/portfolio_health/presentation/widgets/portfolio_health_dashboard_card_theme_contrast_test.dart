// The portfolio-health card paints a heart icon and, while it loads, a spinner
// in the accent. In light they are the deeper blue text colour; in dark the
// dark blue.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

/// A score that never arrives (the card is loading), or none (not enough data).
class _Health extends PortfolioHealth {
  _Health({required this.loading});

  final bool loading;

  @override
  Future<PortfolioHealthScore?> build() =>
      loading ? Completer<PortfolioHealthScore?>().future : Future.value(null);
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required bool loading,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isPortfolioHealthEnabledProvider.overrideWithValue(true),
        portfolioHealthProvider.overrideWith(() => _Health(loading: loading)),
        historicalHealthScoresProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: PortfolioHealthDashboardCard()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Color _heart(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.favorite_outline)).color!;

Color _spinner(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
    .valueColor!
    .value!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final loading in [false, true]) {
    final state = loading ? 'loading' : 'no score yet';

    testWidgets('$state, in light: the heart is the deeper blue and reads', (
      tester,
    ) async {
      await _pump(tester, AppTheme.lightTheme, loading: loading);

      expect(_heart(tester), AppColors.accentTextLight);
      expect(
        contrastRatio(_heart(tester), AppColors.cardLight),
        greaterThanOrEqualTo(kMinGraphic),
      );
      if (loading) {
        expect(_spinner(tester), AppColors.accentTextLight);
      }
      // The card is titled: colour is not the only carrier.
      expect(find.text('Portfolio Health'), findsOneWidget);
    });

    testWidgets('$state, in dark: the heart is the dark blue', (tester) async {
      await _pump(tester, AppTheme.darkTheme, loading: loading);

      expect(_heart(tester), AppColors.accentDark);
      if (loading) {
        expect(_spinner(tester), AppColors.accentDark);
      }
    });
  }
}
