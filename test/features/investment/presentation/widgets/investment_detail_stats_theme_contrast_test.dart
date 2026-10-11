// The investment detail paints a gain in the green and a loss in the red: the
// return badge and the maturity row sit on a tint of that colour, the net
// position figure on the card. Each is pumped in light and measured on the
// ground it sits on. Colour is not the only carrier: the badge starts with +
// or -, and the maturity row says "Matured ... days ago".
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

// Demo figures only.
InvestmentEntity _closed({DateTime? maturity}) => InvestmentEntity(
  id: 'fd-1',
  name: 'Demo FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.closed,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  startDate: DateTime(2024, 1, 1),
  maturityDate: maturity,
  currency: 'INR',
);

InvestmentStats _stats({required double invested, required double returned}) =>
    InvestmentStats(
      totalInvested: invested,
      totalReturned: returned,
      netCashFlow: returned - invested,
      absoluteReturn: (returned - invested) / invested * 100,
      moic: returned / invested,
      xirr: (returned - invested) / invested,
      xirrMethod: XirrMethod.exact,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2024, 1, 1),
      lastCashFlowDate: DateTime(2026, 1, 1),
    );

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentEntity investment,
  required InvestmentStats stats,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
      ],
      child: MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvestmentDetailStatsSection(
              stats: stats,
              investment: investment,
              isDark: false,
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
              isPrivacyMode: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tint behind [text]: the fill of the nearest Container around it that
/// has one, over [ground], the way it is painted.
Color _tintBehind(WidgetTester tester, Finder text, Color ground) {
  for (final element
      in find.ancestor(of: text, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the text.');
}

/// The one [text] that sits on a tint (a fill under half strength), not on the
/// card itself: the return badge, not the XIRR figure with the same digits.
Finder _onATint(WidgetTester tester, String text) {
  final onTint = <Element>[];
  for (final element in find.text(text).evaluate()) {
    for (final box
        in find
            .ancestor(
              of: find.byElementPredicate((e) => e == element),
              matching: find.byType(Container),
            )
            .evaluate()) {
      final decoration = (box.widget as Container).decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        if (decoration.color!.a < 0.5) onTint.add(element);
        break;
      }
    }
  }
  expect(onTint, hasLength(1), reason: 'one "$text" sits on a tint');
  return find.byElementPredicate((e) => e == onTint.single);
}

void main() {
  // Direction, badge text, text colour, tint source, pair id.
  final cases = [
    (
      'a gain',
      _stats(invested: 100000, returned: 110000),
      '+10.0%',
      AppColors.successLight,
      AppColors.successTintLight,
      'detail-return-badge-success-light@tint15',
    ),
    (
      'a loss',
      _stats(invested: 100000, returned: 50000),
      '-50.0%',
      AppColors.errorLight,
      AppColors.dangerTintLight,
      'detail-return-badge-danger-light@tint15',
    ),
  ];

  for (final (name, stats, badgeText, text, tintSource, id) in cases) {
    testWidgets('$name in light: the return badge reads on its tint ($id)', (
      tester,
    ) async {
      await _pump(tester, investment: _closed(), stats: stats);

      // Colour is not the only carrier: the badge starts with the sign.
      final label = _onATint(tester, badgeText);
      expect(tester.widget<Text>(label).style!.color, text);
      final tint = _tintBehind(tester, label, AppColors.cardLight);
      expect(
        tint,
        composeOver(tintSource.withValues(alpha: 0.15), AppColors.cardLight),
      );
      expect(
        contrastRatio(text, tint),
        greaterThanOrEqualTo(kMinText),
        reason: id,
      );
    });
  }

  testWidgets(
    'a matured investment in light: the maturity row reads on its tint '
    '(detail-maturity-matured-light@tint15)',
    (tester) async {
      await _pump(
        tester,
        investment: _closed(maturity: DateTime(2025, 1, 1)),
        stats: _stats(invested: 100000, returned: 110000),
      );

      final status = find.textContaining('Matured');
      expect(status, findsOneWidget, reason: 'the status is written out');
      expect(tester.widget<Text>(status).style!.color, AppColors.successLight);
      final tint = _tintBehind(tester, status, AppColors.cardLight);
      expect(
        tint,
        composeOver(
          AppColors.successTintLight.withValues(alpha: 0.15),
          AppColors.cardLight,
        ),
      );
      expect(
        contrastRatio(AppColors.successLight, tint),
        greaterThanOrEqualTo(kMinText),
        reason: 'detail-maturity-matured-light@tint15',
      );
    },
  );
}
