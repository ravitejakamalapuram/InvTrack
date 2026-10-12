// A warning insight paints its value and its icon in amber. In light they are
// the deeper amber text colour; the disc behind the icon stays tinted with the
// bright amber. In dark they use the dark amber.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/smart_insight_card.dart';

import '../../../../helpers/contrast.dart';

// Demo figures only.
final _insight = SmartInsight(
  type: InsightType.upcomingMaturity,
  priority: InsightPriority.warning,
  title: 'Demo insight',
  subtitle: 'Demo subtitle',
  value: '3 due',
  icon: 'warning',
  generatedAt: DateTime(2026, 10, 11),
);

Future<void> _pump(WidgetTester tester, ThemeData theme) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(body: SmartInsightCard(insight: _insight)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'insight-warning-value-light@card and insight-warning-icon-light@tint20: '
    'the value and the icon read in light',
    (tester) async {
      await _pump(tester, AppTheme.lightTheme);

      final value = find.text('3 due');
      expect(value, findsOneWidget);
      final text = tester.widget<Text>(value).style!.color!;
      expect(text, AppColors.warningTextLight);
      expect(
        contrastRatio(text, AppColors.cardLight),
        greaterThanOrEqualTo(kMinText),
        reason: 'insight-warning-value-light@card',
      );

      final icon = find.byIcon(Icons.warning_amber_rounded);
      expect(tester.widget<Icon>(icon).color, AppColors.warningTextLight);
      // The disc is the bright amber at 20% over the card.
      final disc = tester
          .widgetList<Container>(
            find.ancestor(of: icon, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null && d.color!.a < 0.5)
          .color!;
      expect(disc, AppColors.warningLight.withValues(alpha: 0.2));
      expect(
        contrastRatio(
          AppColors.warningTextLight,
          composeOver(disc, AppColors.cardLight),
        ),
        greaterThanOrEqualTo(kMinGraphic),
        reason: 'insight-warning-icon-light@tint20',
      );
    },
  );

  testWidgets('in dark the value and the icon are the dark amber', (
    tester,
  ) async {
    await _pump(tester, AppTheme.darkTheme);

    expect(
      tester.widget<Text>(find.text('3 due')).style!.color,
      AppColors.warningDark,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
      AppColors.warningDark,
    );
  });
}
