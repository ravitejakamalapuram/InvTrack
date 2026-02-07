import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_fab_widgets.dart';

void main() {
  testWidgets('TransactionFab has correct semantics', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionFab(
            hasTransactions: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // Verify visual presence
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    final handle = tester.ensureSemantics();

    // Verify semantics
    // We expect to find a semantics node with label 'Add Transaction'
    final semanticsFinder = find.bySemanticsLabel('Add Transaction');
    expect(semanticsFinder, findsOneWidget, reason: 'Should find a widget with semantic label "Add Transaction"');

    // Get the semantics node
    final semanticsNode = tester.getSemantics(semanticsFinder);
    final semanticsData = semanticsNode.getSemanticsData();

    // Check for button flag
    // ignore: deprecated_member_use
    expect(semanticsData.hasFlag(SemanticsFlag.isButton), isTrue,
        reason: 'The element labeled "Add Transaction" should be announced as a button');

    // Verify tap action is exposed to semantics
    expect(semanticsData.hasAction(SemanticsAction.tap), isTrue,
        reason: 'Should be tappable via accessibility service');

    // Verify actual tap works
    await tester.tap(find.byType(TransactionFab));
    expect(tapped, isTrue);

    handle.dispose();
  });
}
