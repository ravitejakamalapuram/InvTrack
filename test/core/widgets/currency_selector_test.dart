import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/currency_selector.dart';

void main() {
  group('CurrencySelector Widget Tests', () {
    testWidgets('displays selected currency correctly', (tester) async {
      String selectedCurrency = 'USD';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CurrencySelector(
                selectedCurrency: selectedCurrency,
                onCurrencySelected: (code) {},
                label: 'Test Currency',
                subtitle: 'Select currency',
              ),
            ),
          ),
        ),
      );

      // Verify selected currency is displayed
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('US Dollar (\$)'), findsOneWidget);
    });

    testWidgets('shows currency picker on tap', (tester) async {
      String selectedCurrency = 'USD';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CurrencySelector(
                selectedCurrency: selectedCurrency,
                onCurrencySelected: (code) {},
                label: 'Test Currency',
                subtitle: 'Select currency',
              ),
            ),
          ),
        ),
      );

      // Tap the currency selector (tap on the GlassCard inside)
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      // Verify modal bottom sheet is shown
      expect(find.text('Select Currency'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search field
    });

    testWidgets('allows currency selection', (tester) async {
      String selectedCurrency = 'USD';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return CurrencySelector(
                    selectedCurrency: selectedCurrency,
                    onCurrencySelected: (code) {
                      setState(() => selectedCurrency = code);
                    },
                    label: 'Test Currency',
                    subtitle: 'Select currency',
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open currency picker (tap on the USD text)
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      // Select EUR (tap on EUR code in the list)
      await tester.tap(find.text('EUR').first);
      await tester.pumpAndSettle();

      // Verify EUR is now selected
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('Euro (€)'), findsOneWidget);
    });

    testWidgets('search filters currencies', (tester) async {
      String selectedCurrency = 'USD';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CurrencySelector(
                selectedCurrency: selectedCurrency,
                onCurrencySelected: (code) {},
                label: 'Test Currency',
                subtitle: 'Select currency',
              ),
            ),
          ),
        ),
      );

      // Open currency picker (tap on the USD text)
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'INR');
      await tester.pump(); // Trigger rebuild
      await tester.pump(const Duration(milliseconds: 100)); // Wait for state update
      await tester.pumpAndSettle();

      // Verify only INR is shown in the filtered list
      expect(find.text('Indian Rupee (₹)'), findsOneWidget);

      // Note: The main widget (outside modal) still shows USD, so we check
      // that there's only ONE "US Dollar ($)" text (the main widget, not in modal list)
      expect(find.text('US Dollar (\$)'), findsOneWidget);
    });

    testWidgets('displays custom label and subtitle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CurrencySelector(
                selectedCurrency: 'USD',
                onCurrencySelected: (code) {},
                label: 'Investment Currency',
                subtitle: 'Primary currency for this investment',
              ),
            ),
          ),
        ),
      );

      // Verify custom label and subtitle
      expect(find.text('Investment Currency'), findsOneWidget);
      expect(find.text('Primary currency for this investment'), findsOneWidget);
    });
  });
}

