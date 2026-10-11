// A40 (#783) PR-2: once the record is written, nothing after it may tell the
// user "Nothing was saved". Only the write can fail the save; the analytics of
// the new investment, and the navigation, come after it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

import '../../../../helpers/inter_font.dart';
import '../../../../mocks/mock_analytics_service.dart';
import 'add_investment_harness.dart';

/// Analytics that fail when the form reports the fields of a new investment.
class _FailingAnalytics extends FakeAnalyticsService {
  @override
  Future<void> logEnhancedFieldsUsed({
    required String investmentType,
    required List<String> fieldsUsed,
  }) => throw StateError('analytics is down');

  @override
  Future<void> logSmartDefaultApplied({required String fieldName}) =>
      throw StateError('analytics is down');
}

void main() {
  setUpAll(loadInterFont);

  testWidgets('analytics that fail after the save do not fail the save', (
    tester,
  ) async {
    final harness = await pumpAddForm(
      tester,
      flagOn: true,
      now: DateTime(2026, 10, 11, 14, 30),
      analyticsService: _FailingAnalytics(),
    );
    // A Fixed Deposit sets a payout mode: there are fields to report.
    final chip = find.byKey(
      AddInvestmentKeys.typeChip(InvestmentType.fixedDeposit),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.enterText(nameField(), 'Grip FD');
    await tester.enterText(fieldIn(AddInvestmentKeys.amount), '100000');
    await tester.pump();

    await tester.tap(find.byKey(AddInvestmentKeys.submit));
    await tester.pumpAndSettle();

    expect(harness.adds, hasLength(1));
    expect(
      find.text('Could not add this investment. Nothing was saved. Try again.'),
      findsNothing,
    );
    expect(find.text('Investment created successfully'), findsOneWidget);
    expect(find.byType(AddInvestmentScreen), findsNothing);
    expect(find.text('Detail ${harness.adds.single.id}'), findsOneWidget);
  });
}
