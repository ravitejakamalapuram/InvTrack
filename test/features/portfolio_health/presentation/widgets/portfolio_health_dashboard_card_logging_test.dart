// A127: the dashboard card hides itself when the score fails to load. It must
// report that failure once, not on every rebuild of the card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/crashlytics_recorder.dart';

var _loads = 0;

class _FailingHealth extends PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() async {
    _loads++;
    throw StateError('score failed');
  }
}

// An upstream failure is rethrown unchanged on every retry, so Riverpod's
// automatic retries see the same Exception instance each time.
final _sameError = Exception('upstream failed');

class _SameErrorHealth extends PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() async {
    _loads++;
    throw _sameError;
  }
}

Widget _app(
  ThemeMode mode, {
  bool enabled = true,
  PortfolioHealth Function() health = _FailingHealth.new,
}) => ProviderScope(
  overrides: [
    isPortfolioHealthEnabledProvider.overrideWithValue(enabled),
    portfolioHealthProvider.overrideWith(health),
  ],
  child: MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: mode,
    themeAnimationDuration: Duration.zero,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: PortfolioHealthDashboardCard()),
  ),
);

void main() {
  testWidgets('one load failure is recorded once across 3 rebuilds', (
    tester,
  ) async {
    final records = recordCrashReports();

    // Each theme change rebuilds the card with the same error.
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(_app(mode));
      await tester.pumpAndSettle();
    }

    expect(find.byType(SizedBox), findsWidgets);
    expect(records, hasLength(1));
    expect(
      records.single.reason,
      'PortfolioHealthDashboardCard error | Metadata: '
      'widget=PortfolioHealthDashboardCard',
    );
  });

  testWidgets('a persistent failure retried with the same error is recorded '
      'once', (tester) async {
    final records = recordCrashReports();
    _loads = 0;

    await tester.pumpWidget(
      _app(ThemeMode.light, health: _SameErrorHealth.new),
    );
    // Let Riverpod run all of its automatic retries.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 2));
    }

    expect(_loads, greaterThan(1));
    expect(records, hasLength(1));
  });

  testWidgets('a disabled card neither loads the score nor reports', (
    tester,
  ) async {
    final records = recordCrashReports();
    _loads = 0;

    await tester.pumpWidget(_app(ThemeMode.light, enabled: false));
    await tester.pumpAndSettle();

    expect(_loads, 0);
    expect(records, isEmpty);
  });
}
