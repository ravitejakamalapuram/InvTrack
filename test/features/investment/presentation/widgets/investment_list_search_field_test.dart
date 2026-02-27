import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_search_field.dart';

void main() {
  testWidgets('InvestmentListSearchField has accessible buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: InvestmentListSearchField())),
      ),
    );

    // Verify "Close search" button is present and accessible
    final closeButtonFinder = find.byTooltip('Close search');
    expect(closeButtonFinder, findsOneWidget);
  });

  testWidgets('InvestmentListSearchField clear button is accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: InvestmentListSearchField())),
      ),
    );

    // Enter text to show Clear button
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump();

    final clearButton = find.byTooltip('Clear text');
    expect(clearButton, findsOneWidget);
  });
}
