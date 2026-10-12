// The Needs Attention count on the Reports home sits on the page, in a tint of
// the theme's error colour. In light the error colour is the deeper red, so
// the tint is the brighter red and light enough (10%) for the count to keep
// 4.5:1 on it: on the 20% tint of the deeper red it was 3.85:1. In dark it is
// the dark red at 20%, as before. The heading says "Needs Attention" and the
// count is a number, so colour is not the only carrier.
//
// The id in a test name is a row of test/core/theme/contrast_pairs.dart; the
// guard finds it here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/features/reports/presentation/providers/action_required_provider.dart';
import 'package:inv_tracker/features/reports/presentation/providers/smart_insights_provider.dart';
import 'package:inv_tracker/features/reports/presentation/screens/reports_home_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _NoScore extends PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() async => null;
}

final _urgent = SmartInsight(
  type: InsightType.upcomingMaturity,
  priority: InsightPriority.urgent,
  title: 'Demo insight',
  subtitle: 'Demo subtitle',
  value: 'X',
  icon: 'warning',
  generatedAt: DateTime(2026, 10, 11),
);

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        portfolioHealthProvider.overrideWith(_NoScore.new),
        smartInsightsProvider.overrideWith((ref, l10n) async => const []),
        priorityInsightsProvider.overrideWith((ref, l10n) async => [_urgent]),
        activeGoalsProvider.overrideWith((ref) => Stream.value(const [])),
        actionRequiredReportProvider.overrideWith(
          (ref) async => const ActionRequiredReport(
            criticalActions: [],
            highPriorityActions: [],
            mediumPriorityActions: [],
            lowPriorityActions: [],
            totalActions: 0,
            overdueActions: 0,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tint behind the count: the fill of the Container around it.
Color _fill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.ancestor(of: find.text('1'), matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  // The theme builds text styles from fonts that are not bundled for tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'reports-attention-count-light@tint10: the count reads on its tint in light',
    (tester) async {
      await _pump(tester, AppTheme.lightTheme);

      expect(find.text('Needs Attention'), findsOneWidget);
      final count = tester.widget<Text>(find.text('1'));
      expect(count.style!.color, AppColors.errorLight);
      // The tint is the brighter red, at 10%, over the page.
      final tint = composeOver(_fill(tester), AppColors.backgroundLight);
      expect(
        tint,
        composeOver(
          AppColors.dangerTintLight.withValues(alpha: 0.1),
          AppColors.backgroundLight,
        ),
      );
      expect(
        contrastRatio(count.style!.color!, tint),
        greaterThanOrEqualTo(kMinText),
        reason: 'reports-attention-count-light@tint10',
      );
    },
  );

  testWidgets('the count reads on its tint in dark, as before', (tester) async {
    await _pump(tester, AppTheme.darkTheme);

    final count = tester.widget<Text>(find.text('1'));
    expect(count.style!.color, AppColors.errorDark);
    final tint = composeOver(_fill(tester), AppColors.surfaceDark);
    expect(
      tint,
      composeOver(
        AppColors.errorDark.withValues(alpha: 0.2),
        AppColors.surfaceDark,
      ),
    );
    expect(
      contrastRatio(count.style!.color!, tint),
      greaterThanOrEqualTo(kMinText),
    );
  });
}
