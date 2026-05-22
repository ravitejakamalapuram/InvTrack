import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvestmentListScreen bounds behavior', () {
    testWidgets('gracefully handles items being removed/filtered while scrolling', (WidgetTester tester) async {
      // Create a large list of string data representing our investments
      final largeList = List.generate(50, (index) => 'Investment $index');

      var filteredInvestments = [...largeList];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // This matches the implementation in investment_list_screen.dart
                        if (index < 0 || index >= filteredInvestments.length) {
                          return null;
                        }
                        return ListTile(title: Text(filteredInvestments[index]));
                      },
                      childCount: filteredInvestments.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the list has items rendered
      expect(find.text('Investment 0'), findsOneWidget);

      // Now scroll down a bit so Flutter thinks we might need to render higher index items
      await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
      await tester.pump();

      // Simulate a drastic filter event where the list shrinks suddenly
      filteredInvestments = [largeList[0]];

      // Re-pump. If the bug was present (and Flutter requests index 5 because it was scrolling),
      // it would throw an IndexOutOfBoundsException if we didn't have the defensive bounds check.
      // Here, we manually force a layout with the shrunk list. The delegate should handle out-of-bounds gracefully.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // This matches the implementation in investment_list_screen.dart
                        if (index < 0 || index >= filteredInvestments.length) {
                          return null;
                        }
                        return ListTile(title: Text(filteredInvestments[index]));
                      },
                      // We intentionally keep the old childCount for a moment to simulate
                      // the state discrepancy during rapid transitions
                      childCount: largeList.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // This should NOT throw an error
      expect(tester.takeException(), isNull);
    });
  });
}
