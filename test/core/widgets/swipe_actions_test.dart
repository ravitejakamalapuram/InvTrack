// Tests for SwipeActions widget.
import 'package:flutter/material.dart';
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
        home: Scaffold(
          body: ListView(
            children: [widget],
          ),
        ),
      ),
    );
  }

  group('SwipeActions - Configuration', () {
    testWidgets('should render child when no actions configured',
        (tester) async {
      await pumpSwipeActions(
        tester,
        const SwipeActions(
          itemKey: 'test-item',
          child: Text('Test Item'),
        ),
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

    testWidgets('should wrap with Dismissible when delete action configured',
        (tester) async {
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

    testWidgets('should wrap with Dismissible when archive action configured',
        (tester) async {
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

    testWidgets('should wrap with Dismissible when both actions configured',
        (tester) async {
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
    testWidgets('should allow only endToStart when only delete configured',
        (tester) async {
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

    testWidgets('should allow only startToEnd when only archive configured',
        (tester) async {
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

    testWidgets('should allow horizontal when both actions configured',
        (tester) async {
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
}

