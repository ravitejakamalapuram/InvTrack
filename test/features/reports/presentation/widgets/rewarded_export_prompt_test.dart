import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/rewarded_export_prompt.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Future<bool?> _open(
  WidgetTester tester, {
  required Future<void> Function() tap,
  bool afterExport = false,
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showRewardedExportPrompt(
              context,
              afterExport: afterExport,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tap();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('explains the ad and never mentions money', (tester) async {
    await _open(tester, tap: () async {});
    expect(find.text('Watch a short ad to export?'), findsOneWidget);
    expect(find.textContaining('never share your investments'), findsOneWidget);
    expect(find.text('Watch ad'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('after an export it asks for support, not permission', (
    tester,
  ) async {
    await _open(tester, tap: () async {}, afterExport: true);
    expect(find.text('Help keep InvTrack free?'), findsOneWidget);
    expect(find.text('Watch a short ad to export?'), findsNothing);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Watch ad answers yes', (tester) async {
    final result = await _open(
      tester,
      tap: () => tester.tap(find.text('Watch ad')),
    );
    expect(result, isTrue);
  });

  testWidgets('Not now answers no', (tester) async {
    final result = await _open(
      tester,
      tap: () => tester.tap(find.text('Not now')),
    );
    expect(result, isFalse);
  });

  testWidgets('tapping outside answers no', (tester) async {
    final result = await _open(
      tester,
      tap: () => tester.tapAt(const Offset(5, 5)),
    );
    expect(result, isFalse);
  });
}
