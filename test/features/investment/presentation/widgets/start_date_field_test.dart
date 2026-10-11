// A40 (#783) PR-2: the start date field of the add investment form. It shows
// the date, opens a picker on tap (the caller shows it), carries the helper
// that says the date also dates the first cash flow, and is one button for a
// screen reader.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/start_date_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Widget _host({
  required DateTime date,
  String? helper,
  VoidCallback? onTap,
  double textScale = 1.0,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: StartDateField(date: date, helper: helper, onTap: onTap ?? () {}),
    ),
  ),
);

void main() {
  final today = DateTime(2026, 10, 11);

  testWidgets('shows the label and the date as "Oct 11, 2026"', (tester) async {
    await tester.pumpWidget(_host(date: today));

    expect(find.byType(AppTextField), findsOneWidget);
    expect(
      tester.widget<AppTextField>(find.byType(AppTextField)).label,
      'Start Date',
    );
    expect(
      find.descendant(
        of: find.byType(StartDateField),
        matching: find.text('Oct 11, 2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new date replaces the text', (tester) async {
    await tester.pumpWidget(_host(date: today));
    await tester.pumpWidget(_host(date: DateTime(2026, 10, 5)));

    expect(find.text('Oct 5, 2026'), findsOneWidget);
    expect(find.text('Oct 11, 2026'), findsNothing);
  });

  testWidgets('the helper is there only when given', (tester) async {
    await tester.pumpWidget(_host(date: today));
    expect(find.textContaining('first cash flow'), findsNothing);

    await tester.pumpWidget(
      _host(
        date: today,
        helper: 'Today. Also the date of your first cash flow.',
      ),
    );
    expect(
      find.text('Today. Also the date of your first cash flow.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the field, its label or its helper opens the picker', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        date: today,
        helper: 'Also the date of your first cash flow.',
        onTap: () => taps++,
      ),
    );

    await tester.tap(find.text('Oct 11, 2026'));
    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    expect(taps, 2);
  });

  testWidgets('typing cannot edit the date: the field is read-only', (
    tester,
  ) async {
    await tester.pumpWidget(_host(date: today));

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.readOnly, isTrue);
  });

  testWidgets('one button for a screen reader: label, long date, helper', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        date: today,
        helper: 'Today. Also the date of your first cash flow.',
      ),
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel('Select Start Date'),
    );
    expect(
      node,
      matchesSemantics(
        label: 'Select Start Date',
        value:
            'October 11, 2026. Today. Also the date of your first cash flow.',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('without a helper the spoken value is the date alone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(date: today));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Select Start Date')),
      matchesSemantics(
        label: 'Select Start Date',
        value: 'October 11, 2026',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the target is at least 48dp high, also at text 1.8x', (
    tester,
  ) async {
    await tester.pumpWidget(_host(date: today));
    expect(
      tester.getSize(find.byType(TextFormField)).height,
      greaterThanOrEqualTo(48.0),
    );

    await tester.pumpWidget(_host(date: today, textScale: 1.8));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TextFormField)).height,
      greaterThanOrEqualTo(48.0),
    );
  });
}
