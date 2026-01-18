import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_search_field.dart';

void main() {
  testWidgets('InvestmentListSearchField renders correctly and has accessible close button',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InvestmentListSearchField(),
          ),
        ),
      ),
    );

    // Verify search field exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    // Verify close button is now an IconButton with correct tooltip
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byTooltip('Close search'), findsOneWidget);
  });
}
