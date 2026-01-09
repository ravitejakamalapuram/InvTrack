import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';

void main() {
  testWidgets('TypeSelector chips have correct semantics', (WidgetTester tester) async {
    String selectedValue = 'A';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TypeSelector<String>(
                label: 'Select Type',
                values: const ['A', 'B'],
                selectedValue: selectedValue,
                onSelected: (val) => setState(() => selectedValue = val),
                colorBuilder: (_) => Colors.red,
                iconBuilder: (_) => Icons.abc,
                labelBuilder: (val) => 'Type $val',
              );
            },
          ),
        ),
      ),
    );

    // Verify visual presence
    expect(find.text('Type A'), findsOneWidget);
    expect(find.text('Type B'), findsOneWidget);

    // Check Semantics for Type A (Selected)
    // We expect "Type A" to be selected and be a button.

    // Find semantics that match our expectation.
    // Since we are looking for accessibility improvements, we want to ensure
    // that there is a semantic node that labels "Type A", is a button, and is selected.

    // Note: If TypeSelector uses Semantics with explicit label, we can find by that label.
    // If it relies on child text, the label might be "Type A".

    // Inspect the semantics tree
    final SemanticsHandle handle = tester.ensureSemantics();

    // Check for Type A (Selected)
    expect(
      tester.getSemantics(find.bySemanticsLabel('Type A')),
      matchesSemantics(
        label: 'Type A',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );

    // Check for Type B (Not Selected)
    expect(
      tester.getSemantics(find.bySemanticsLabel('Type B')),
      matchesSemantics(
        label: 'Type B',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
        isFocusable: true,
      ),
    );

    handle.dispose();
  });
}
