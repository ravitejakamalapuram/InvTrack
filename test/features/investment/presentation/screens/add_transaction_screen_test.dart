import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/currency_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  group('isReviewPromptSuccessMoment', () {
    test('a new (non-editing) return/exit is a success moment', () {
      expect(
        isReviewPromptSuccessMoment(
          isEditing: false,
          type: CashFlowType.returnFlow,
        ),
        isTrue,
      );
    });

    test('editing an existing return/exit is not a success moment', () {
      expect(
        isReviewPromptSuccessMoment(
          isEditing: true,
          type: CashFlowType.returnFlow,
        ),
        isFalse,
      );
    });

    for (final type in [
      CashFlowType.invest,
      CashFlowType.income,
      CashFlowType.fee,
    ]) {
      test('a new $type is never a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: false, type: type),
          isFalse,
        );
      });
    }
  });

  group('AddTransactionScreen currency', () {
    final usdInvestment = InvestmentEntity(
      id: 'inv-usd',
      name: 'US Treasury',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: 'USD',
    );

    Future<void> pumpScreen(WidgetTester tester) async {
      // Tall enough that the whole form (selector and preview) is built.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The user's base currency is INR; the investment is in USD.
            currencyCodeProvider.overrideWithValue('INR'),
            investmentByIdProvider(
              'inv-usd',
            ).overrideWith((ref) async => usdInvestment),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTransactionScreen(investmentId: 'inv-usd'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? amountPrefix(WidgetTester tester) => tester
        .widgetList<AppTextField>(find.byType(AppTextField))
        .firstWhere((f) => f.label == 'Amount')
        .prefixText;

    testWidgets('a USD investment starts with USD selected and a \$ prefix', (
      tester,
    ) async {
      await pumpScreen(tester);

      final selector = tester.widget<CurrencySelector>(
        find.byType(CurrencySelector),
      );
      expect(selector.selectedCurrency, 'USD');
      expect(amountPrefix(tester), '\$');
    });

    testWidgets('the preview shows the amount in the investment currency', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount').first,
        '1000',
      );
      await tester.pumpAndSettle();

      expect(find.text('-\$1,000.00'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });
  });
}
