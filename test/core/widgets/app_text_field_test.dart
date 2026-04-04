import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';

void main() {
  testWidgets('AppTextField shows clear button only when text is not empty', (
    WidgetTester tester,
  ) async {
    // Create a controller to check text updates
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            label: 'Test Field',
            hint: 'Enter text',
          ),
        ),
      ),
    );

    // Initial state: empty, no clear button
    expect(
      find.byType(TextField),
      findsOneWidget,
    ); // AppTextField uses TextFormField which uses TextField
    expect(find.byIcon(Icons.cancel), findsNothing);

    // Enter text "a"
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();

    // Should show clear button
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    // Enter more text "ab"
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();

    // Should still show clear button
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    // Clear text
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Should hide clear button
    expect(find.byIcon(Icons.cancel), findsNothing);

    // Test tapping clear button
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump();
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('AppTextField does not show clear button when readOnly is true', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'test');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(controller: controller, readOnly: true),
        ),
      ),
    );

    // Initial state: has text, but readOnly, so no clear button
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('AppTextField external FocusNode focus test', (
    WidgetTester tester,
  ) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(label: 'Click Me', focusNode: focusNode),
        ),
      ),
    );

    expect(focusNode.hasFocus, isFalse);

    // find.text finds both the external label and the internal hidden label of InputDecorator.
    // The external label is the first child of the Column.
    await tester.tap(find.text('Click Me').first);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('AppTextField internal FocusNode focus test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppTextField(label: 'Click Me Internal')),
      ),
    );

    final editableTextFinder = find.byType(EditableText);
    expect(editableTextFinder, findsOneWidget);

    // Tap the external label (first occurrence)
    await tester.tap(find.text('Click Me Internal').first);
    await tester.pump();

    // Verify it has focus
    final editableText = tester.widget<EditableText>(editableTextFinder);
    expect(editableText.focusNode.hasFocus, isTrue);
  });

  testWidgets('AppTextField semantics test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppTextField(label: 'Semantic Label')),
      ),
    );

    // We expect 2 Text widgets:
    // 1. The visible external label
    // 2. The internal (hidden but present) label in InputDecorator
    expect(find.text('Semantic Label'), findsNWidgets(2));

    // Ensure semantics are generated
    final handle = tester.ensureSemantics();

    // find.bySemanticsLabel should find 1 node with this label: the internal one.
    // The external visual label is wrapped in ExcludeSemantics so it is NOT read.
    // This confirms that the TextField (via InputDecorator) is announcing the label,
    // and the ExcludeSemantics wrapper prevents double reading.
    final finder = find.bySemanticsLabel('Semantic Label');
    expect(finder, findsOneWidget);

    handle.dispose();
  });
}
