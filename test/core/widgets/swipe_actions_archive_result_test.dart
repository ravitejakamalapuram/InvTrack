// A17 / GAP1-04: the swipe-to-archive gesture used to fire `onArchive`
// without awaiting it and always showed the success message, even when the
// archive failed. The message now follows the result, and the confirm dialog
// can carry details (the goals an archive would change).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, ArchiveActionConfig config) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            SwipeActions(
              itemKey: 'item',
              archiveConfig: config,
              child: const SizedBox(height: 80, child: Text('Test Item')),
            ),
          ],
        ),
      ),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold)));

Future<void> _swipeAndConfirm(WidgetTester tester) async {
  await tester.drag(find.text('Test Item'), const Offset(500, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, _l10n(tester).archive));
  await tester.pump();
}

void main() {
  testWidgets('the success message waits until the archive has finished', (
    tester,
  ) async {
    final done = Completer<void>();
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () => done.future,
        successMessage: 'Investment archived',
        failureMessage: 'Could not archive',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Investment archived'), findsNothing);

    done.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Investment archived'), findsOneWidget);
    expect(find.text('Could not archive'), findsNothing);
  });

  testWidgets('a failed archive shows the failure message, not success', (
    tester,
  ) async {
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () => Future<void>.error(Exception('offline')),
        successMessage: 'Investment archived',
        failureMessage: 'Could not archive',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not archive'), findsOneWidget);
    expect(find.text('Investment archived'), findsNothing);
  });

  testWidgets('a callback that returns nothing still shows success', (
    tester,
  ) async {
    var archived = 0;
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () => archived++,
        successMessage: 'Investment archived',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(archived, 1);
    expect(find.text('Investment archived'), findsOneWidget);
  });

  testWidgets('confirm details are shown in the dialog', (tester) async {
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () {},
        successMessage: 'Investment archived',
        confirmDetails: () async => const Text('House: 76% to 0%'),
      ),
    );

    await tester.drag(find.text('Test Item'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Sure?'), findsOneWidget);
    expect(find.text('House: 76% to 0%'), findsOneWidget);
  });

  testWidgets('a failed archive without its own message says so from the '
      'localisation file, not a hardcoded string', (tester) async {
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () => Future<void>.error(Exception('offline')),
        successMessage: 'Archived',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_l10n(tester).archiveActionFailed), findsOneWidget);
    expect(
      _l10n(tester).archiveActionFailed,
      'Something went wrong. Please try again.',
    );
    expect(find.text('Archived'), findsNothing);
  });

  testWidgets('the confirm button reads Unarchive for an archived item', (
    tester,
  ) async {
    var restored = 0;
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Unarchive?',
        confirmMessage: 'Sure?',
        onArchive: () => restored++,
        successMessage: 'Restored',
        isArchived: true,
      ),
    );

    await tester.drag(find.text('Test Item'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Archive'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).unarchive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(restored, 1);
    expect(find.text('Restored'), findsOneWidget);
  });

  testWidgets('declining the dialog archives nothing', (tester) async {
    var archived = 0;
    await _pump(
      tester,
      ArchiveActionConfig(
        confirmTitle: 'Archive?',
        confirmMessage: 'Sure?',
        onArchive: () => archived++,
        successMessage: 'Investment archived',
      ),
    );

    await tester.drag(find.text('Test Item'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(archived, 0);
    expect(find.text('Investment archived'), findsNothing);
  });
}
