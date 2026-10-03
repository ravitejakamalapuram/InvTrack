import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// One open FD of Rs10,00,000 with no payout yet, as calculateStats returns it.
final _openNoPayout = InvestmentStats(
  totalInvested: 1000000,
  totalReturned: 0,
  netCashFlow: -1000000,
  absoluteReturn: -100,
  moic: 0,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

/// A closed investment: Rs1,00,000 in, Rs1,25,000 back after two years.
final _closed = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 125000,
  netCashFlow: 25000,
  absoluteReturn: 25,
  moic: 1.25,
  xirr: 0.118,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentStats stats,
  required InvestmentStats openStats,
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OverviewQuickStats(stats: stats, openStats: openStats),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OverviewQuickStats MOIC tile', () {
    testWidgets(
      'open portfolio with no payout shows a neutral dash and the hint, '
      'never a green 0.00x',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Phone width: the hint must wrap inside the tile, not overflow.
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pump(tester, stats: _openNoPayout, openStats: _openNoPayout);

        expect(find.text('—'), findsOneWidget);
        expect(
          find.text('Add a payout or current value to calculate'),
          findsOneWidget,
        );
        expect(find.text('0.00x'), findsNothing);
        expect(
          find.bySemanticsLabel(
            'MOIC: —, Add a payout or current value to calculate',
          ),
          findsOneWidget,
        );
        final icon = tester.widget<Icon>(find.byIcon(Icons.trending_up));
        expect(icon.color, AppColors.neutral500Light);
        handle.dispose();
      },
    );

    testWidgets('privacy mode masks the awaiting tile and hides the hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        stats: _openNoPayout,
        openStats: _openNoPayout,
        privacy: true,
      );

      expect(find.text('0.00x'), findsNothing);
      expect(find.bySemanticsLabel('MOIC: Hidden amount'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('portfolio with nothing open still shows its MOIC', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, stats: _closed, openStats: InvestmentStats.empty());

      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.bySemanticsLabel('MOIC: 1.25x, over 2.0y'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.trending_up));
      expect(icon.color, AppColors.successLight);
      handle.dispose();
    });
  });
}
