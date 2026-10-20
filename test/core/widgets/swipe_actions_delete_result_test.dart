// A26 / UX-25: the swipe-to-delete gesture used to fire `onDelete` without
// awaiting it and always showed the success message. The message now follows
// the result, like the archive swipe.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, DeleteActionConfig config) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            SwipeActions(
              itemKey: 'item',
              deleteConfig: config,
              child: const SizedBox(height: 80, child: Text('Test Item')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _swipeAndConfirm(WidgetTester tester) async {
  await tester.drag(find.text('Test Item'), const Offset(-500, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Delete'));
  await tester.pump();
}

void main() {
  testWidgets('the success message waits until the delete has finished', (
    tester,
  ) async {
    final done = Completer<void>();
    await _pump(
      tester,
      DeleteActionConfig(
        confirmTitle: 'Delete?',
        confirmMessage: 'Sure?',
        onDelete: () => done.future,
        successMessage: 'Deleted it',
        failureMessage: 'Could not delete',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted it'), findsNothing);

    done.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted it'), findsOneWidget);
    expect(find.text('Could not delete'), findsNothing);
  });

  testWidgets('a failed delete shows the error, not the success message', (
    tester,
  ) async {
    await _pump(
      tester,
      DeleteActionConfig(
        confirmTitle: 'Delete?',
        confirmMessage: 'Sure?',
        onDelete: () => throw StateError('rejected'),
        successMessage: 'Deleted it',
        failureMessage: 'Could not delete',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not delete'), findsOneWidget);
    expect(find.text('Deleted it'), findsNothing);
  });

  testWidgets('a failed delete says so even with no failureMessage set', (
    tester,
  ) async {
    await _pump(
      tester,
      DeleteActionConfig(
        confirmTitle: 'Delete?',
        confirmMessage: 'Sure?',
        onDelete: () => Future<void>.error(StateError('rejected')),
        successMessage: 'Deleted it',
      ),
    );

    await _swipeAndConfirm(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Deleted it'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.deleteActionFailed), findsOneWidget);
  });
}
