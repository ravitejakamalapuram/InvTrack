// A22 (#764, INV-05): the edit form pre-fills every optional field, and a
// field the user clears must reach InvestmentNotifier.updateInvestment as
// null while untouched fields carry their stored value. The notifier relies
// on this to persist cleared fields (see investment_notifier_clear_fields_test).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _SavedEdit {
  _SavedEdit(this.values);
  final Map<String, Object?> values;
}

class _RecordingNotifier extends InvestmentNotifier {
  _RecordingNotifier(this.saved);
  final List<_SavedEdit> saved;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<void> updateInvestment({
    required String id,
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
  }) async {
    saved.add(
      _SavedEdit({
        'id': id,
        'notes': notes,
        'maturityDate': maturityDate,
        'incomeFrequency': incomeFrequency,
        'startDate': startDate,
        'expectedRate': expectedRate,
        'tenureMonths': tenureMonths,
        'platform': platform,
        'interestPayoutMode': interestPayoutMode,
        'autoRenewal': autoRenewal,
        'riskLevel': riskLevel,
        'compoundingFrequency': compoundingFrequency,
        'currency': currency,
      }),
    );
  }
}

final _investment = InvestmentEntity(
  id: 'inv-fd',
  name: 'HDFC FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  notes: 'Old notes',
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  maturityDate: DateTime(2027, 4, 1),
  incomeFrequency: IncomeFrequency.quarterly,
  startDate: DateTime(2026, 4, 1),
  expectedRate: 7.25,
  tenureMonths: 12,
  platform: 'HDFC Bank',
  interestPayoutMode: InterestPayoutMode.periodic,
  autoRenewal: true,
  riskLevel: RiskLevel.low,
  compoundingFrequency: CompoundingFrequency.quarterly,
  currency: 'INR',
);

Finder _editableWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  testWidgets('clearing fields in the edit form sends them as null', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = <_SavedEdit>[];
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Detail')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) =>
                  AddInvestmentScreen(investmentToEdit: _investment),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          currencySymbolProvider.overrideWithValue('₹'),
          currencyLocaleProvider.overrideWithValue('en_IN'),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          investmentNotifierProvider.overrideWith(
            () => _RecordingNotifier(saved),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;

    // Notes and platform: empty the text fields.
    await tester.enterText(_editableWithText('Old notes'), '');
    await tester.scrollUntilVisible(
      _editableWithText('HDFC Bank'),
      200,
      scrollable: scrollable,
    );
    await tester.enterText(_editableWithText('HDFC Bank'), '');

    // Maturity date: the clear (x) button.
    final clearMaturity = find.byTooltip('Clear maturity date');
    await tester.scrollUntilVisible(clearMaturity, 200, scrollable: scrollable);
    await tester.tap(clearMaturity);
    await tester.pumpAndSettle();
    expect(clearMaturity, findsNothing);

    // Income frequency: "None".
    final none = find.bySemanticsLabel('None income frequency');
    await tester.scrollUntilVisible(none, 200, scrollable: scrollable);
    await tester.tap(none);
    await tester.pumpAndSettle();

    final save = find.text('Save Changes');
    await tester.scrollUntilVisible(save, 200, scrollable: scrollable);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    final values = saved.single.values;
    expect(values['id'], 'inv-fd');
    // Cleared by the user.
    expect(values['notes'], isNull);
    expect(values['platform'], isNull);
    expect(values['maturityDate'], isNull);
    expect(values['incomeFrequency'], isNull);
    // Untouched: sent with the stored value.
    expect(values['startDate'], DateTime(2026, 4, 1));
    expect(values['expectedRate'], 7.25);
    expect(values['tenureMonths'], 12);
    expect(values['interestPayoutMode'], InterestPayoutMode.periodic);
    expect(values['autoRenewal'], isTrue);
    expect(values['riskLevel'], RiskLevel.low);
    expect(values['compoundingFrequency'], CompoundingFrequency.quarterly);
    expect(values['currency'], 'INR');
  });
}
