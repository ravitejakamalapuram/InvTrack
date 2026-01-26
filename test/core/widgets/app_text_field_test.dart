import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';

void main() {
  testWidgets('AppTextField shows clear button only when text is not empty', (WidgetTester tester) async {
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
    expect(find.byType(TextField), findsOneWidget); // AppTextField uses TextFormField which uses TextField
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

  testWidgets('AppTextField does not show clear button when readOnly is true', (WidgetTester tester) async {
    final controller = TextEditingController(text: 'test');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            readOnly: true,
          ),
        ),
      ),
    );

    // Initial state: has text, but readOnly, so no clear button
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}
