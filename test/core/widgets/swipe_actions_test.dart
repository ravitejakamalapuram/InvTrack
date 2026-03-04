// Tests for SwipeActions widget.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';

void main() {
  /// Helper to pump widget with MaterialApp wrapper.
  Future<void> pumpSwipeActions(
    WidgetTester tester,
    SwipeActions widget,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListView(children: [widget])),
      ),
    );
  }

  bool hasSemanticsAction(WidgetTester tester, Finder finder, String label) {
    final semantics = tester.getSemantics(finder);
    bool found = false;

    // We use a separate recursive function to walk the tree
    // because visitChildren expects a bool-returning callback.
    bool visit(SemanticsNode node) {
      if (found) return false; // Stop if already found

      final data = node.getSemanticsData();
      if (data.customSemanticsActionIds != null) {
        for (final id in data.customSemanticsActionIds!) {
          final action = CustomSemanticsAction.getAction(id);
          if (action?.label == label) {
            found = true;
            return false; // Stop visiting
          }
        }
      }

      node.visitChildren(visit);
      return true; // Continue visiting
    }

    // Check the root node first
    final data = semantics.getSemanticsData();
    if (data.customSemanticsActionIds != null) {
      for (final id in data.customSemanticsActionIds!) {
        final action = CustomSemanticsAction.getAction(id);
        if (action?.label == label) {
          return true;
        }
      }
    }

    // Then check children
    semantics.visitChildren(visit);
    return found;
  }

  group('SwipeActions - Configuration', () {
    testWidgets('should render child when no actions configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        const SwipeActions(itemKey: 'test-item', child: Text('Test Item')),
      );

      expect(find.text('Test Item'), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('should render child when disabled', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          enabled: false,
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const Text('Test Item'),
        ),
      );

      expect(find.text('Test Item'), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('should wrap with Dismissible when delete action configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const Text('Test Item'),
        ),
      );

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('should wrap with Dismissible when archive action configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
          ),
          child: const Text('Test Item'),
        ),
      );

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('should wrap with Dismissible when both actions configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
          ),
          child: const Text('Test Item'),
        ),
      );

      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  group('SwipeActions - Direction', () {
    testWidgets('should allow only endToStart when only delete configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const Text('Test Item'),
        ),
      );

      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.endToStart);
    });

    testWidgets('should allow only startToEnd when only archive configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
          ),
          child: const Text('Test Item'),
        ),
      );

      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.startToEnd);
    });

    testWidgets('should allow horizontal when both actions configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
          ),
          child: const Text('Test Item'),
        ),
      );

      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.horizontal);
    });
  });

  group('SwipeActions - ArchiveActionConfig', () {
    testWidgets('should show archive icon when not archived', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
            isArchived: false,
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      // Swipe right to reveal archive background
      await tester.drag(find.text('Test Item'), const Offset(100, 0));
      await tester.pump();

      expect(find.byIcon(Icons.archive_rounded), findsOneWidget);
    });

    testWidgets('should show unarchive icon when archived', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Unarchive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Unarchived',
            isArchived: true,
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      // Swipe right to reveal unarchive background
      await tester.drag(find.text('Test Item'), const Offset(100, 0));
      await tester.pump();

      expect(find.byIcon(Icons.unarchive_rounded), findsOneWidget);
    });
  });

  group('SwipeActions - Delete Background', () {
    testWidgets('should show delete icon when swiping left', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      // Swipe left to reveal delete background
      await tester.drag(find.text('Test Item'), const Offset(-100, 0));
      await tester.pump();

      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    });
  });

  group('SwipeActions - Item Key', () {
    testWidgets('should use itemKey for Dismissible key', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'unique-key-123',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const Text('Test Item'),
        ),
      );

      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.key, const Key('unique-key-123'));
    });
  });

  group('SwipeActions - Accessibility', () {
    testWidgets('should expose Delete action in semantics when configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      // Verify that 'Delete' action is present in semantics
      final hasDelete = hasSemanticsAction(
        tester,
        find.byType(SwipeActions),
        'Delete',
      );

      expect(hasDelete, isTrue, reason: 'Expected Delete action in semantics');
    });

    testWidgets('should expose Archive action in semantics when configured', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
            isArchived: false,
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      final hasArchive = hasSemanticsAction(
        tester,
        find.byType(SwipeActions),
        'Archive',
      );

      expect(
        hasArchive,
        isTrue,
        reason: 'Expected Archive action in semantics',
      );
    });

    testWidgets('should expose Unarchive action when item is archived', (
      tester,
    ) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Unarchive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Unarchived',
            isArchived: true,
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      final hasUnarchive = hasSemanticsAction(
        tester,
        find.byType(SwipeActions),
        'Unarchive',
      );

      expect(
        hasUnarchive,
        isTrue,
        reason: 'Expected Unarchive action in semantics',
      );
    });

    testWidgets('should expose both actions when configured', (tester) async {
      await pumpSwipeActions(
        tester,
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
          ),
          child: const SizedBox(height: 60, child: Text('Test Item')),
        ),
      );

      expect(
        hasSemanticsAction(tester, find.byType(SwipeActions), 'Delete'),
        isTrue,
      );
      expect(
        hasSemanticsAction(tester, find.byType(SwipeActions), 'Archive'),
        isTrue,
      );
    });
  });
}
