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
  // A42: INCOME (an interest payout) is as much a success moment as a
  // RETURN, and is far more common for FD, bond and P2P users, so it now
  // earns the one-shot prompt too. This replaces the earlier test that
  // pinned INCOME as never a success moment.
  group('isReviewPromptSuccessMoment', () {
    for (final type in [CashFlowType.returnFlow, CashFlowType.income]) {
      test('a new (non-editing) $type is a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: false, type: type),
          isTrue,
        );
      });

      test('editing an existing $type is not a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: true, type: type),
          isFalse,
        );
      });
    }

    for (final type in [CashFlowType.invest, CashFlowType.fee]) {
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

  // The preview must show what will be stored: the amount rounded to the
  // currency's minor unit (JPY none, INR two), not always two decimals.
  group('AddTransactionScreen preview precision', () {
    InvestmentEntity investment(String id, String currency) => InvestmentEntity(
      id: id,
      name: 'Deal $currency',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: currency,
    );

    Future<void> enterAmount(
      WidgetTester tester, {
      required String currency,
      required String text,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final id = 'inv-$currency';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            investmentByIdProvider(
              id,
            ).overrideWith((ref) async => investment(id, currency)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTransactionScreen(investmentId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount').first,
        text,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a JPY amount previews as whole yen', (tester) async {
      await enterAmount(tester, currency: 'JPY', text: '125.6');

      expect(find.text('-¥126'), findsOneWidget);
      expect(find.text('-¥125.60'), findsNothing);
    });

    testWidgets('an INR amount previews rounded half away from zero', (
      tester,
    ) async {
      await enterAmount(tester, currency: 'INR', text: '1.005');

      expect(find.text('-₹1.01'), findsOneWidget);
    });
  });
}
