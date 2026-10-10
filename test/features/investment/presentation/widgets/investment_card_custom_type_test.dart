// #936: an investment of type Other shows its custom label where the card
// said "Other", in the visible chip and in the screen-reader label. An Other
// investment with no label (every one saved before this) still shows "Other",
// and nothing changes while the feature flag is off.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

InvestmentEntity _investment({
  InvestmentType type = InvestmentType.other,
  String? label,
}) => InvestmentEntity(
  id: 'inv-1',
  name: 'Stamp album',
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  currency: 'INR',
  customTypeLabel: label,
);

Future<void> _pump(
  WidgetTester tester,
  InvestmentEntity investment, {
  required bool flag,
}) async {
  final stats = InvestmentStats(
    totalInvested: 10000,
    totalReturned: 0,
    netCashFlow: -10000,
    absoluteReturn: 0,
    moic: 0,
    xirr: 0,
    cashFlowCount: 1,
    firstCashFlowDate: DateTime(2025, 1, 1),
    lastCashFlowDate: DateTime(2025, 1, 1),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        investmentBasicStatsProvider(
          investment.id,
        ).overrideWith((ref) => AsyncValue.data(stats)),
        investmentXirrProvider(investment.id).overrideWith(
          (ref) => Future.value(
            const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
          ),
        ),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyFormatProvider.overrideWith(
          (ref) => NumberFormat.currency(symbol: '₹'),
        ),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
  await tester.pumpAndSettle();
}

String _semanticLabel(WidgetTester tester) =>
    tester.getSemantics(find.byType(GlassCard)).label;

void main() {
  testWidgets('a custom label replaces "Other" in the chip and the label', (
    tester,
  ) async {
    await _pump(tester, _investment(label: 'Stamps'), flag: true);

    expect(find.text('Stamps'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    expect(_semanticLabel(tester), contains('Stamps'));
    expect(_semanticLabel(tester), isNot(contains('Other')));
  });

  testWidgets('an Other investment saved before custom types still shows '
      '"Other"', (tester) async {
    await _pump(tester, _investment(), flag: true);

    expect(find.text('Other'), findsOneWidget);
    expect(_semanticLabel(tester), contains('Other'));
  });

  testWidgets('with the flag off the label is not shown', (tester) async {
    await _pump(tester, _investment(label: 'Stamps'), flag: false);

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Stamps'), findsNothing);
    expect(_semanticLabel(tester), isNot(contains('Stamps')));
  });

  testWidgets('a built-in type keeps its own name', (tester) async {
    await _pump(
      tester,
      _investment(type: InvestmentType.bonds, label: 'Stamps'),
      flag: true,
    );

    expect(find.text('Bonds/Debentures'), findsOneWidget);
    expect(find.text('Stamps'), findsNothing);
  });
}
