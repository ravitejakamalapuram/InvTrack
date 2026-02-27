import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_filter_tabs.dart';

void main() {
  testWidgets('InvestmentListFilterTabs keyboard navigation test', (tester) async {
    // Setup
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentCountsProvider.overrideWithValue(
            (all: 10, open: 5, closed: 3, archived: 2),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: InvestmentListFilterTabs(),
          ),
        ),
      ),
    );

    // Initial check
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    // Press Tab to focus the first chip ('All')
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Press Tab to focus the second chip ('Open')
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Press Enter to select 'Open'
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Verify "Open" is selected.
    final openText = tester.widget<Text>(find.text('Open'));

    expect(openText.style?.fontWeight, FontWeight.w600,
        reason: 'Open chip should be selected after pressing Enter');
  });
}
