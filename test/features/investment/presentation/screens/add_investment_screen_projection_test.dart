// A16 (#761, CALC-08): the "Estimated Returns" card on the add form uses the
// RD formula for the Recurring Deposit template and compounds a Fixed Deposit
// quarterly when no frequency is chosen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _IdleNotifier extends InvestmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
}

Future<void> _pumpForm(
  WidgetTester tester, {
  InvestmentTemplate? template,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWithValue('INR'),
        currencySymbolProvider.overrideWithValue('₹'),
        currencyLocaleProvider.overrideWithValue('en_IN'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        investmentNotifierProvider.overrideWith(_IdleNotifier.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddInvestmentScreen(preselectedTemplate: template),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterField(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.byType(EditableText),
  );
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _showInterestRow(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Interest Earned'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('RD template: Rs1L over 12 months @6.5% earns Rs3.57K', (
    tester,
  ) async {
    await _pumpForm(tester, template: InvestmentTemplates.recurringDeposit);
    await _showInterestRow(tester);

    // 12 installments of 8,333.33: interest 3,572.05, maturity 1,03,572.05.
    // The lump-sum formula showed +6.66K on a 1.07L maturity.
    expect(find.text('+₹6.66K'), findsNothing);
    expect(find.text('+₹3.57K'), findsOneWidget);
    expect(find.text('₹1.04L'), findsOneWidget);
  });

  testWidgets('Fixed Deposit with no compounding chosen compounds quarterly', (
    tester,
  ) async {
    await _pumpForm(tester);

    // The type chip, not the FD template (which sets Quarterly itself).
    await tester.tap(
      find.descendant(
        of: find.byType(TypeSelector<InvestmentType>),
        matching: find.text('Fixed Deposit'),
      ),
    );
    await tester.pumpAndSettle();
    await _enterField(tester, 'Expected Return Rate (% p.a.)', '7');
    await _enterField(tester, 'Tenure (Months)', '60');
    await _showInterestRow(tester);

    // Rs1L @7% for 5 years: 1,41,477.82 quarterly (annual gave 1,40,255.17).
    expect(find.text('+₹40.3K'), findsNothing);
    expect(find.text('+₹41.5K'), findsOneWidget);
    expect(find.text('₹1.41L'), findsOneWidget);
  });
}
