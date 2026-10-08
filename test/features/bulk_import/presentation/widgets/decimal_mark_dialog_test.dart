import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/presentation/widgets/decimal_mark_dialog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  /// Opens the dialog; [answers] receives what it returns.
  Future<void> open(WidgetTester tester, List<bool?> answers) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answers.add(await showDecimalMarkDialog(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains the question with fixed examples', (tester) async {
    await open(tester, []);

    expect(find.text(_l10n.importDecimalMarkTitle), findsOneWidget);
    expect(find.text(_l10n.importDecimalMarkMessage), findsOneWidget);
    expect(find.text('Point (1,234.56)'), findsOneWidget);
    expect(find.text('Comma (1.234,56)'), findsOneWidget);
  });

  for (final (label, answer) in [
    ('Point (1,234.56)', false),
    ('Comma (1.234,56)', true),
    ('Cancel', null),
  ]) {
    testWidgets('$label returns $answer', (tester) async {
      final answers = <bool?>[];
      await open(tester, answers);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(answers, [answer]);
    });
  }
}
