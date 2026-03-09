import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';

void main() {
  testWidgets('TypeSelector chips have correct semantics', (
    WidgetTester tester,
  ) async {
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
        hasSelectedState: true,
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
        hasSelectedState: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('TypeSelector handles keyboard focus and selection', (
    WidgetTester tester,
  ) async {
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

    // Initial state: A is selected
    expect(selectedValue, 'A');

    // Press Tab to focus the first chip (should be 'Type A')
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Verify that something has focus. Since GestureDetector is not focusable by default,
    // this test will fail if TypeSelector doesn't handle focus correctly.
    // In a properly implemented accessible widget, the first chip should have focus.

    // We can check if 'Type A' has focus by checking the focus node associated with it.
    // However, finding by widget and checking focus is tricky with custom widgets.
    // Instead, we can check if the primary focus is within the TypeSelector.
    // But since there are no other focusable widgets, focusing *anything* inside means success.

    final focusedNode = FocusManager.instance.primaryFocus;
    expect(focusedNode, isNotNull);
    expect(focusedNode!.context, isNotNull);

    // Verify the focused widget is related to 'Type A'
    // Since we can't easily introspect the widget tree for focus ownership without keys,
    // let's rely on the interaction flow.

    // Press Tab again to move to 'Type B'
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Now 'Type B' should be focused.
    // Press Enter to select 'Type B'
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Verify selection changed
    expect(selectedValue, 'B');

    // Press Shift+Tab to move back to 'Type A'
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    // Press Space to select 'Type A'
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    // Verify selection changed back
    expect(selectedValue, 'A');
  });
}
