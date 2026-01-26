// Golden tests for SwipeActions widget.
//
// Tests visual appearance of swipe action backgrounds (delete and archive).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('SwipeActions Golden Tests', () {
    testWidgets('delete background - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                '← Swipe left to delete',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.cardSize,
      );

      // Swipe to reveal delete background
      await tester.drag(
        find.text('← Swipe left to delete'),
        const Offset(-150, 0),
      );
      await tester.pump();

      await expectLater(
        find.byType(SwipeActions),
        matchesGoldenFile('goldens/swipe_actions_delete_light.png'),
      );
    });

    testWidgets('delete background - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        SwipeActions(
          itemKey: 'test-item',
          deleteConfig: DeleteActionConfig(
            confirmTitle: 'Delete',
            confirmMessage: 'Are you sure?',
            onDelete: () {},
            successMessage: 'Deleted',
          ),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '← Swipe left to delete',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.cardSize,
      );

      await tester.drag(
        find.text('← Swipe left to delete'),
        const Offset(-150, 0),
      );
      await tester.pump();

      await expectLater(
        find.byType(SwipeActions),
        matchesGoldenFile('goldens/swipe_actions_delete_dark.png'),
      );
    });

    testWidgets('archive background - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
            isArchived: false,
          ),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                'Swipe right to archive →',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.cardSize,
      );

      // Swipe to reveal archive background
      await tester.drag(
        find.text('Swipe right to archive →'),
        const Offset(150, 0),
      );
      await tester.pump();

      await expectLater(
        find.byType(SwipeActions),
        matchesGoldenFile('goldens/swipe_actions_archive_light.png'),
      );
    });

    testWidgets('archive background - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        SwipeActions(
          itemKey: 'test-item',
          archiveConfig: ArchiveActionConfig(
            confirmTitle: 'Archive',
            confirmMessage: 'Are you sure?',
            onArchive: () {},
            successMessage: 'Archived',
            isArchived: false,
          ),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Swipe right to archive →',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.cardSize,
      );

      await tester.drag(
        find.text('Swipe right to archive →'),
        const Offset(150, 0),
      );
      await tester.pump();

      await expectLater(
        find.byType(SwipeActions),
        matchesGoldenFile('goldens/swipe_actions_archive_dark.png'),
      );
    });
  });
}
