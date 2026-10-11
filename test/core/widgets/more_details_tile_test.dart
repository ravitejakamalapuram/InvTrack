// A40 (#783) PR-2: the collapsed "More details" tile of the add investment
// form. The caller owns whether it is open (so the answer survives rebuilds),
// the children exist only while it is open, the header is a button that says
// whether it is expanded, and it is at least 64dp high.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/more_details_tile.dart';

Widget _host({
  required bool expanded,
  required ValueChanged<bool> onChanged,
  double width = 411,
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: MoreDetailsTile(
              title: 'More details',
              summary: 'Currency, rate, term, notes and more',
              expanded: expanded,
              onChanged: onChanged,
              children: const [
                TextField(key: Key('child-field')),
                Text('Second child'),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('collapsed: title and summary show, children do not exist', (
    tester,
  ) async {
    await tester.pumpWidget(_host(expanded: false, onChanged: (_) {}));

    expect(find.text('More details'), findsOneWidget);
    expect(find.text('Currency, rate, term, notes and more'), findsOneWidget);
    expect(find.byKey(const Key('child-field')), findsNothing);
    expect(find.text('Second child'), findsNothing);
  });

  testWidgets('expanded: the children are there, in order, below the header', (
    tester,
  ) async {
    await tester.pumpWidget(_host(expanded: true, onChanged: (_) {}));
    await tester.pumpAndSettle();

    final header = tester.getRect(find.text('More details'));
    final field = tester.getRect(find.byKey(const Key('child-field')));
    final second = tester.getRect(find.text('Second child'));
    expect(field.top, greaterThan(header.bottom));
    expect(second.top, greaterThan(field.bottom - 1));
  });

  testWidgets('tapping the header asks to open, then to close', (tester) async {
    final asked = <bool>[];
    var expanded = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          expanded: expanded,
          onChanged: (value) {
            asked.add(value);
            setState(() => expanded = value);
          },
        ),
      ),
    );

    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-field')), findsOneWidget);

    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-field')), findsNothing);
    expect(asked, [true, false]);
  });

  testWidgets(
    'the caller decides: a tap that is not accepted changes nothing',
    (tester) async {
      final asked = <bool>[];
      await tester.pumpWidget(_host(expanded: false, onChanged: asked.add));

      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();

      expect(asked, [true]);
      expect(find.byKey(const Key('child-field')), findsNothing);
    },
  );

  testWidgets('the header is a button that says whether it is expanded', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(expanded: false, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('More details')),
      matchesSemantics(
        label: 'More details',
        hint: 'Currency, rate, term, notes and more',
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );

    await tester.pumpWidget(_host(expanded: true, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('More details')),
      matchesSemantics(
        label: 'More details',
        hint: 'Currency, rate, term, notes and more',
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the header is at least 64dp high, collapsed and open', (
    tester,
  ) async {
    await tester.pumpWidget(_host(expanded: false, onChanged: (_) {}));
    final collapsed = tester.getSize(find.byType(MoreDetailsTile)).height;
    expect(collapsed, greaterThanOrEqualTo(64.0));

    await tester.pumpWidget(_host(expanded: true, onChanged: (_) {}));
    await tester.pumpAndSettle();
    final headerHeight = tester
        .getRect(
          find.ancestor(
            of: find.text('Currency, rate, term, notes and more'),
            matching: find.byType(InkWell),
          ),
        )
        .height;
    expect(headerHeight, greaterThanOrEqualTo(64.0));
  });

  for (final brightness in Brightness.values) {
    testWidgets('no overflow at 320dp and text 1.8x (${brightness.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final expanded in [false, true]) {
        await tester.pumpWidget(
          _host(
            expanded: expanded,
            onChanged: (_) {},
            width: 320,
            textScale: 1.8,
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'expanded=$expanded');
        final box = tester.getRect(find.byType(MoreDetailsTile));
        expect(box.right, lessThanOrEqualTo(320));
      }
    });
  }
}
