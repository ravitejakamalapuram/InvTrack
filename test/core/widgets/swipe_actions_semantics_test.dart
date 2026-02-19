import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';

void main() {
  testWidgets('SwipeActions exposes Delete custom semantics action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActions(
            itemKey: 'test-item',
            deleteConfig: DeleteActionConfig(
              confirmTitle: 'Delete?',
              confirmMessage: 'Sure?',
              onDelete: () {},
              successMessage: 'Deleted',
            ),
            child: const Text('Swipe me'),
          ),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    final finder = find.text('Swipe me');

    final semanticsNode = tester.getSemantics(finder);
    final semantics = semanticsNode.getSemanticsData();
    final actionLabels = _getCustomActionLabels(semantics);

    expect(actionLabels, contains('Delete'));

    handle.dispose();
  });

  testWidgets('SwipeActions exposes Archive custom semantics action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActions(
            itemKey: 'test-item',
            archiveConfig: ArchiveActionConfig(
              confirmTitle: 'Archive?',
              confirmMessage: 'Sure?',
              onArchive: () {},
              successMessage: 'Archived',
              isArchived: false,
            ),
            child: const Text('Swipe me'),
          ),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    final finder = find.text('Swipe me');

    final semanticsNode = tester.getSemantics(finder);
    final semantics = semanticsNode.getSemanticsData();
    final actionLabels = _getCustomActionLabels(semantics);

    expect(actionLabels, contains('Archive'));

    handle.dispose();
  });

  testWidgets('SwipeActions exposes Unarchive custom semantics action when archived', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActions(
            itemKey: 'test-item',
            archiveConfig: ArchiveActionConfig(
              confirmTitle: 'Unarchive?',
              confirmMessage: 'Sure?',
              onArchive: () {},
              successMessage: 'Unarchived',
              isArchived: true,
            ),
            child: const Text('Swipe me'),
          ),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    final finder = find.text('Swipe me');

    final semanticsNode = tester.getSemantics(finder);
    final semantics = semanticsNode.getSemanticsData();
    final actionLabels = _getCustomActionLabels(semantics);

    expect(actionLabels, contains('Unarchive'));

    handle.dispose();
  });

  testWidgets('SwipeActions exposes both Delete and Archive actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActions(
            itemKey: 'test-item',
            deleteConfig: DeleteActionConfig(
              confirmTitle: 'Delete?',
              confirmMessage: 'Sure?',
              onDelete: () {},
              successMessage: 'Deleted',
            ),
            archiveConfig: ArchiveActionConfig(
              confirmTitle: 'Archive?',
              confirmMessage: 'Sure?',
              onArchive: () {},
              successMessage: 'Archived',
              isArchived: false,
            ),
            child: const Text('Swipe me'),
          ),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    final finder = find.text('Swipe me');

    final semanticsNode = tester.getSemantics(finder);
    final semantics = semanticsNode.getSemanticsData();
    final actionLabels = _getCustomActionLabels(semantics);

    expect(actionLabels, contains('Delete'));
    expect(actionLabels, contains('Archive'));

    handle.dispose();
  });
}

List<String> _getCustomActionLabels(SemanticsData data) {
  final labels = <String>[];
  if (data.customSemanticsActionIds != null) {
    for (final id in data.customSemanticsActionIds!) {
      final action = CustomSemanticsAction.getAction(id);
      if (action != null && action.label != null) {
        labels.add(action.label!);
      }
    }
  }
  return labels;
}
