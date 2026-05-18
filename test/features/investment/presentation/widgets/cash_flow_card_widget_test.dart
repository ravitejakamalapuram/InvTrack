import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/cash_flow_card_widget.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCurrencyConversionService extends Mock
    implements CurrencyConversionService {}

void main() {
  late MockCurrencyConversionService mockConversionService;

  setUp(() async {
    mockConversionService = MockCurrencyConversionService();
    // Set up SharedPreferences with privacy mode disabled
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  });

  group('CashFlowCardWidget Multi-Currency Tests', () {
    final testCashFlow = CashFlowEntity(
      id: 'test_1',
      investmentId: 'inv_1',
      type: CashFlowType.invest,
      amount: 1000,
      currency: 'USD',
      date: DateTime(2024, 1, 1),
      notes: 'Test transaction',
      createdAt: DateTime(2024, 1, 1),
    );

    final currencyFormat = NumberFormat.currency(symbol: '\$');

    testWidgets(
      'shows exchange rate when currency differs from base currency',
      (tester) async {
        // Mock exchange rate
        when(
          () => mockConversionService.getRate(
            from: 'USD',
            to: 'INR',
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => 83.12);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currencyCodeProvider.overrideWith(
                (ref) => 'INR',
              ), // Base currency
              currencyConversionServiceProvider.overrideWith(
                (ref) => mockConversionService,
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CashFlowCardWidget(
                  cashFlow: testCashFlow,
                  isDark: false,
                  currencyFormat: currencyFormat,
                  onTap: () {},
                  onEdit: () {},
                  onConfirmDelete: () async => false,
                  onDeleted: () {},
                ),
              ),
            ),
          ),
        );

        // Wait for FutureBuilder to complete
        await tester.pumpAndSettle();
        await tester.pump(); // Extra pump for async operations

        // Verify exchange rate icon is shown
        expect(find.byIcon(Icons.currency_exchange_rounded), findsOneWidget);

        // Verify exchange rate text is shown (check for key parts)
        expect(find.textContaining('USD'), findsWidgets);
        expect(find.textContaining('INR'), findsWidgets);
      },
    );

    testWidgets('hides exchange rate when currency matches base currency', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'USD'), // Same currency
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CashFlowCardWidget(
                cashFlow: testCashFlow,
                isDark: false,
                currencyFormat: currencyFormat,
                onTap: () {},
                onEdit: () {},
                onConfirmDelete: () async => false,
                onDeleted: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(); // Extra pump

      // Verify exchange rate icon is NOT shown (same currency)
      expect(find.byIcon(Icons.currency_exchange_rounded), findsNothing);
    });

    testWidgets('displays correct exchange rate format', (tester) async {
      // Mock exchange rate
      when(
        () => mockConversionService.getRate(
          from: 'EUR',
          to: 'USD',
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => 1.0850);

      final eurCashFlow = testCashFlow.copyWith(currency: 'EUR', amount: 500);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'USD'),
            currencyConversionServiceProvider.overrideWith(
              (ref) => mockConversionService,
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CashFlowCardWidget(
                cashFlow: eurCashFlow,
                isDark: false,
                currencyFormat: currencyFormat,
                onTap: () {},
                onEdit: () {},
                onConfirmDelete: () async => false,
                onDeleted: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(); // Extra pump for async

      // Verify exchange rate format contains key parts
      expect(find.textContaining('EUR'), findsWidgets);
      expect(find.textContaining('USD'), findsWidgets);
    });

    testWidgets('shows currency exchange icon', (tester) async {
      when(
        () => mockConversionService.getRate(
          from: 'USD',
          to: 'INR',
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => 83.12);

      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'INR'),
            currencyConversionServiceProvider.overrideWith(
              (ref) => mockConversionService,
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CashFlowCardWidget(
                cashFlow: testCashFlow,
                isDark: false,
                currencyFormat: currencyFormat,
                onTap: () {},
                onEdit: () {},
                onConfirmDelete: () async => false,
                onDeleted: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(); // Extra pump

      // Find the currency exchange icon
      final iconFinder = find.byIcon(Icons.currency_exchange_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify icon size
      final Icon icon = tester.widget(iconFinder);
      expect(icon.size, 11);
    });
  });
}
