// A123 (#897): Retry on the Overview error card must show that it ran and
// whether it worked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(
    WidgetTester tester, {
    bool retrying = false,
    bool retryFailed = false,
    VoidCallback? onRetry,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: OverviewLoadErrorState(
          onRetry: onRetry ?? () {},
          retrying: retrying,
          retryFailed: retryFailed,
        ),
      ),
    ),
  );

  testWidgets('while retrying, Retry shows progress, is disabled and says '
      'Retrying', (tester) async {
    var taps = 0;
    await pump(tester, retrying: true, onRetry: () => taps++);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Retrying'), findsOneWidget);
    await tester.tap(find.text(l10n.retry));
    expect(taps, 0);
  });

  testWidgets('a retry that failed again shows the new message', (
    tester,
  ) async {
    await pump(tester, retryFailed: true);
    expect(find.text(l10n.overviewRetryFailed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('first view has no failure message and Retry works', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onRetry: () => taps++);
    expect(find.text(l10n.overviewRetryFailed), findsNothing);
    await tester.tap(find.text(l10n.retry));
    expect(taps, 1);
  });
}
