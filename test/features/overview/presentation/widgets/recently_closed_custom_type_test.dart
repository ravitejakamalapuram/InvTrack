// #936: the Recently Closed row on the overview shows an Other investment's
// custom label under its name instead of "Other", while the feature flag is
// on. The type breakdown on the same screen stays on the built-in type.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

InvestmentWithStats _closed(
  String name, {
  InvestmentType type = InvestmentType.other,
  String? label,
}) => InvestmentWithStats(
  investment: InvestmentEntity(
    id: name,
    name: name,
    type: type,
    status: InvestmentStatus.closed,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    currency: 'INR',
    customTypeLabel: label,
  ),
  stats: const InvestmentStats(
    totalInvested: 10000,
    totalReturned: 12000,
    netCashFlow: 2000,
    absoluteReturn: 20,
    moic: 1.2,
    xirr: 0.2,
    cashFlowCount: 2,
  ),
);

Future<void> _pump(WidgetTester tester, {required bool flag}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
        recentlyClosedInvestmentsProvider.overrideWithValue(
          AsyncValue.data([
            _closed('Stamp album', label: 'Stamps'),
            _closed('Loose change'),
            _closed('Old bond', type: InvestmentType.bonds),
          ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentlyClosedCard(
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag on: the row shows the custom label, others unchanged', (
    tester,
  ) async {
    await _pump(tester, flag: true);

    expect(find.text('Stamps'), findsOneWidget);
    // "Loose change" has no label: still Other; the stamp album is not.
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Bonds/Debentures'), findsOneWidget);
  });

  testWidgets('flag off: every Other row says Other', (tester) async {
    await _pump(tester, flag: false);

    expect(find.text('Stamps'), findsNothing);
    expect(find.text('Other'), findsNWidgets(2));
  });
}
