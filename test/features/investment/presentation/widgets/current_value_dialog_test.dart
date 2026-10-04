// A10 (#754): the current value editor takes a value in the investment's
// currency and a date that defaults to today and cannot be in the future.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/current_value_dialog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Future<CurrentValueEdit?> _open(
  WidgetTester tester, {
  bool canRemove = false,
  required Future<void> Function() interact,
}) async {
  CurrentValueEdit? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<CurrentValueEdit>(
              context: context,
              builder: (_) => CurrentValueDialog(
                currency: 'INR',
                canRemove: canRemove,
                today: DateTime(2026, 10, 2),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await interact();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('saves a value in the investment currency as of today', (
    tester,
  ) async {
    final result = await _open(
      tester,
      interact: () async {
        expect(find.text('Current value'), findsOneWidget);
        expect(find.text('Value in INR'), findsOneWidget);
        expect(find.text('Value as of Oct 2, 2026'), findsOneWidget);
        expect(find.text('Use estimate'), findsNothing);
        await tester.enterText(find.byType(TextFormField), '1,25,000.55');
        await tester.tap(find.text('Save'));
      },
    );

    expect(result, isNotNull);
    expect(result!.isRemove, isFalse);
    expect(result.value, 125000.55);
    expect(result.date, DateTime(2026, 10, 2));
  });

  testWidgets('rejects an empty value', (tester) async {
    final result = await _open(
      tester,
      interact: () async {
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a value of 0 or more'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
      },
    );
    expect(result, isNull);
  });

  testWidgets('offers to go back to the estimate when the user set a value', (
    tester,
  ) async {
    final result = await _open(
      tester,
      canRemove: true,
      interact: () => tester.tap(find.text('Use estimate')),
    );
    expect(result!.isRemove, isTrue);
  });

  // A comma is a thousands or lakh separator only. On a keyboard where it
  // is the decimal separator, '1234,56' must not be saved as 1,23,456.
  for (final text in ['1234,56', '1,56', '1.234,56', '12,3']) {
    testWidgets('rejects "$text", where the comma may be a decimal point', (
      tester,
    ) async {
      final result = await _open(
        tester,
        interact: () async {
          await tester.enterText(find.byType(TextFormField), text);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(find.text('Enter a value of 0 or more'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
        },
      );
      expect(result, isNull);
    });
  }

  for (final (text, value) in [
    ('12,34,567.5', 1234567.5),
    ('1,234,567', 1234567.0),
    ('1234.56', 1234.56),
  ]) {
    testWidgets('reads "$text" as $value', (tester) async {
      final result = await _open(
        tester,
        interact: () async {
          await tester.enterText(find.byType(TextFormField), text);
          await tester.tap(find.text('Save'));
        },
      );
      expect(result!.value, value);
    });
  }
}
