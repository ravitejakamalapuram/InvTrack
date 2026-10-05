import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/bulk_import/presentation/widgets/date_order_dialog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  final question = DateOrderQuestion(
    sample: '05/03/2024',
    dayFirst: DateTime(2024, 3, 5),
    monthFirst: DateTime(2024, 5, 3),
  );

  /// Opens the dialog; [answers] receives what it returns.
  Future<void> open(WidgetTester tester, List<CsvDateOrder?> answers) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answers.add(await showDateOrderDialog(context, question)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sample and both readings of it', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, []);

    expect(find.text(_l10n.importDateOrderTitle), findsOneWidget);
    expect(
      find.text(_l10n.importDateOrderMessage('05/03/2024')),
      findsOneWidget,
    );
    expect(find.text('Day first (5 Mar 2024)'), findsOneWidget);
    expect(find.text('Month first (3 May 2024)'), findsOneWidget);
    expect(find.text(_l10n.cancel), findsOneWidget);
    expect(
      find.bySemanticsLabel(_l10n.importDateOrderDayFirst('5 Mar 2024')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(_l10n.importDateOrderMonthFirst('3 May 2024')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  for (final (label, expected) in [
    ('Day first (5 Mar 2024)', CsvDateOrder.dayFirst),
    ('Month first (3 May 2024)', CsvDateOrder.monthFirst),
  ]) {
    testWidgets('returns $expected for "$label"', (tester) async {
      final answers = <CsvDateOrder?>[];
      await open(tester, answers);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(answers, [expected]);
      expect(find.text(_l10n.importDateOrderTitle), findsNothing);
    });
  }

  testWidgets('cancel returns no order', (tester) async {
    final answers = <CsvDateOrder?>[];
    await open(tester, answers);

    await tester.tap(find.text(_l10n.cancel));
    await tester.pumpAndSettle();

    expect(answers, [null]);
  });
}
