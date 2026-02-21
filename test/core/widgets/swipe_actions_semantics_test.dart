import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';

void main() {
  testWidgets('SwipeActions should have custom semantics actions', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActions(
            itemKey: 'test-item',
            deleteConfig: DeleteActionConfig(
              confirmTitle: 'Delete',
              confirmMessage: 'Confirm?',
              onDelete: () {},
              successMessage: 'Deleted',
            ),
            archiveConfig: ArchiveActionConfig(
              confirmTitle: 'Archive',
              confirmMessage: 'Confirm?',
              onArchive: () {},
              successMessage: 'Archived',
            ),
            child: const Text('Swipe Me'),
          ),
        ),
      ),
    );

    // Find the semantics node for "Swipe Me"
    // Note: Dismissible might wrap the child, so we search for the text.
    final finder = find.text('Swipe Me');
    expect(finder, findsOneWidget);

    final semantics = tester.getSemantics(finder);
    final data = semantics.getSemanticsData();

    // Check custom actions
    final customActions = data.customSemanticsActionIds;

    // If null or empty, it means no custom actions are present
    if (customActions == null || customActions.isEmpty) {
      fail('No custom semantics actions found on the child widget');
    }

    // Helper to find action label by ID
    String? getActionLabel(int id) {
      return CustomSemanticsAction.getAction(id)?.label;
    }

    final labels = customActions.map(getActionLabel).toList();

    expect(labels, contains('Delete'), reason: 'Should verify "Delete" action exists');
    expect(labels, contains('Archive'), reason: 'Should verify "Archive" action exists');

    handle.dispose();
  });
}
