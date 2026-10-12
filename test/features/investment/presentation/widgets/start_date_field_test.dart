// A40 (#783) PR-2: the start date field of the add investment form. It shows
// the date, opens a picker on tap (the caller shows it), carries the helper
// that says the date also dates the first cash flow, and is one button for a
// screen reader.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The field between two buttons, as a hardware keyboard meets it in the form.
Widget _keyboardHost({required VoidCallback onTap}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const ValueKey('before'),
          autofocus: true,
          onPressed: () {},
          child: const Text('Before'),
        ),
        StartDateField(date: DateTime(2026, 10, 11), onTap: onTap),
        TextButton(
          key: const ValueKey('after'),
          onPressed: () {},
          child: const Text('After'),
        ),
      ],
    ),
  ),
);

/// The widget with [key] holds the focus, or something inside it does.
bool _hasFocus(Key key) {
  final primary = FocusManager.instance.primaryFocus?.context;
  if (primary == null) return false;
  if (primary.widget.key == key) return true;
  var inside = false;
  primary.visitAncestorElements((element) {
    inside = element.widget.key == key;
    return !inside;
  });
  return inside;
}

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

  group('a hardware keyboard', () {
    testWidgets('Tab reaches the field and Enter opens the picker', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_keyboardHost(onTap: () => taps++));
      expect(_hasFocus(const ValueKey('before')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
        isTrue,
        reason: 'the field shows its focus state',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('Space and the numpad Enter open the picker too', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_keyboardHost(onTap: () => taps++));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('other keys do nothing, and Tab moves on in one press', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_keyboardHost(onTap: () => taps++));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(taps, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_hasFocus(const ValueKey('after')), isTrue);
    });

    testWidgets('a held key opens the picker once, not on every repeat', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_keyboardHost(onTap: () => taps++));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });

    testWidgets('a date picked in the real picker, opened with the keyboard, '
        'leaves the field focused', (tester) async {
      var date = DateTime(2026, 10, 11);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StartDateField(
                date: date,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2026, 10, 11),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 5, 2026'), findsOneWidget);
      expect(
        tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
        isTrue,
      );
    });
  });
}
