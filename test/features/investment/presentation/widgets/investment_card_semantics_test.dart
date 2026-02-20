import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';

class MockPrivacyModeNotifier extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

void main() {
  testWidgets('InvestmentCard semantics include XIRR when available', (tester) async {
    // 1. Setup Data
    final investment = InvestmentEntity(
      id: 'inv-1',
      name: 'Test Investment',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
      maturityDate: DateTime(2024, 1, 1),
    );

    final stats = InvestmentStats(
      totalInvested: 10000,
      totalReturned: 0,
      netCashFlow: -10000,
      absoluteReturn: 0,
      moic: 1.0,
      xirr: 0.0, // Basic stats have 0 XIRR
      cashFlowCount: 1,
      firstCashFlowDate: DateTime(2023, 1, 1),
      lastCashFlowDate: DateTime(2023, 1, 1),
    );

    final xirrValue = 0.125; // 12.5%

    // 2. Pump Widget with Overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Basic stats provider returns stats with 0 XIRR
          investmentBasicStatsProvider(investment.id).overrideWith(
            (ref) => AsyncValue.data(stats),
          ),
          // XIRR provider returns actual XIRR
          investmentXirrProvider(investment.id).overrideWith(
            (ref) => Future.value(xirrValue),
          ),
          // Mock other dependencies
          currencySymbolProvider.overrideWith((ref) => '\$'),
          currencyFormatProvider.overrideWith(
            (ref) => NumberFormat.currency(symbol: '\$'),
          ),
          privacyModeProvider.overrideWith(MockPrivacyModeNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InvestmentCard(
              investment: investment,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    // Wait for FutureProvider to resolve
    await tester.pumpAndSettle();

    // 3. Verify Semantics
    // The GlassCard wraps content in Semantics with a custom label.
    // We expect the label to contain "Returns: positive 12.5 percent".

    // Find the Semantics widget created inside GlassCard
    final semanticsFinder = find.descendant(
      of: find.byType(InvestmentCard),
      matching: find.byType(Semantics)
    );

    // There might be multiple semantics, we want the one with 'Test Investment'
    // But GlassCard wraps everything in one Semantics with label.

    // Let's try to find semantics that contains the text

    final semanticsNode = tester.getSemantics(find.byType(GlassCard));
    final label = semanticsNode.label;

    // If empty, maybe we grabbed the wrong node or tree isn't built yet?
    // GlassCard builds Semantics only if onTap is not null. We passed onTap: () {}.

    expect(label, contains('Test Investment'));
    // AccessibilityUtils.formatPercentageForScreenReader logic:
    // positive 12.5 percent
    expect(label, contains('positive 12.5 percent'));
  });

  testWidgets('InvestmentCard semantics exclude XIRR when loading/error', (tester) async {
    // 1. Setup Data
    final investment = InvestmentEntity(
      id: 'inv-1',
      name: 'Test Investment',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
      maturityDate: DateTime(2024, 1, 1),
    );

    final stats = InvestmentStats.empty();

    // 2. Pump Widget with Loading XIRR
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentBasicStatsProvider(investment.id).overrideWith(
            (ref) => AsyncValue.data(stats),
          ),
          // XIRR provider is loading
          investmentXirrProvider(investment.id).overrideWith(
            (ref) => Future<double>.delayed(const Duration(seconds: 10)),
          ),
           currencySymbolProvider.overrideWith((ref) => '\$'),
          currencyFormatProvider.overrideWith(
            (ref) => NumberFormat.currency(symbol: '\$'),
          ),
          privacyModeProvider.overrideWith(MockPrivacyModeNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InvestmentCard(
              investment: investment,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump(); // Pump once, but don't settle (loading)

    final semantics = tester.getSemantics(find.byType(GlassCard));
    final label = semantics.label;

    // Should NOT contain "percent" since XIRR is missing/0
    // Note: It might contain "Returns: not available" if logic falls through,
    // but investmentCardLabel checks `if (returns.isNotEmpty)`.
    // And `returns` checks `returnPercent != null`.
    // In InvestmentCard, we pass `xirrValue != 0 ? xirrValue * 100 : null`.
    // If loading, xirrAsync.value is null, fallback to stats.xirr (0).
    // So returnPercent is null. So returns is empty.
    expect(label, isNot(contains('percent')));
  });
}
