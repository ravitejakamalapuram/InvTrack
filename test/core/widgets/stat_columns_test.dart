// StatColumns: equal columns of label over value whose values share one
// baseline, first column on the start edge and last on the end edge.
//
// The test font (Ahem) draws every glyph as a square of the font size, so the
// geometry here is exact. The widget sits at the left of the screen in both
// reading directions, so x is 0 to 300 in both.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/stat_columns.dart';

import '../../helpers/text_geometry.dart';

Widget _app({
  required Widget child,
  double width = 300,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(textDirection: direction, child: app!),
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

StatColumn _col(
  String label,
  String value, {
  String? note,
  double valueSize = 14,
  String? semanticsLabel,
}) => StatColumn(
  label: Text(label, style: const TextStyle(fontSize: 12)),
  value: Text(value, style: TextStyle(fontSize: valueSize)),
  note: note == null ? null : Text(note, style: const TextStyle(fontSize: 10)),
  semanticsLabel: semanticsLabel,
);

Rect _cell(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(StatColumns.cellKey(i)));

void main() {
  group('columnsPerRow', () {
    int perRow({
      required double width,
      required double scale,
      int count = 3,
      double gap = 8,
      int maxPerRow = 3,
      double? min = 72,
    }) => StatColumns.columnsPerRow(
      width: width,
      count: count,
      gap: gap,
      maxPerRow: maxPerRow,
      minColumnWidth: min,
      textScale: scale,
    );

    test(
      'fits three columns on the hero at 360dp only while text is small',
      () {
        // The hero is 288dp wide inside its padding at 360dp.
        expect(perRow(width: 288, scale: 1.0), 3);
        expect(perRow(width: 288, scale: 1.3), 2);
        expect(perRow(width: 288, scale: 1.5), 2);
        expect(perRow(width: 288, scale: 2.0), 1);
      },
    );

    test('fits more columns at 411dp', () {
      // The hero is 339dp wide inside its padding at 411dp.
      expect(perRow(width: 339, scale: 1.0), 3);
      expect(perRow(width: 339, scale: 1.3), 3);
      expect(perRow(width: 339, scale: 1.5), 2);
      expect(perRow(width: 339, scale: 2.0), 2);
    });

    test('never exceeds the number of columns or the cap', () {
      expect(perRow(width: 1000, scale: 1, count: 2), 2);
      expect(perRow(width: 1000, scale: 1, count: 5), 3);
      expect(perRow(width: 1000, scale: 1, count: 5, maxPerRow: 4), 4);
    });

    test('never stacks without a minimum width', () {
      expect(perRow(width: 100, scale: 2.0, min: null), 3);
    });

    test('is one column when even two do not fit', () {
      expect(perRow(width: 100, scale: 2.0), 1);
    });
  });

  test('the cell key is a string key per column', () {
    expect(StatColumns.cellKey(2), const ValueKey('stat-column-2'));
  });

  testWidgets('draws nothing for no columns', (tester) async {
    await tester.pumpWidget(_app(child: const StatColumns(columns: [])));
    expect(tester.getSize(find.byType(StatColumns)).height, 0);
  });

  group('edges alignment', () {
    testWidgets('equal columns, first on the start edge, last on the end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: StatColumns(
            columns: [
              _col('out', '₹1'),
              _col('in', '₹22'),
              _col('XIRR', '9.5%'),
            ],
          ),
        ),
      );

      final a = _cell(tester, 0);
      final b = _cell(tester, 1);
      final c = _cell(tester, 2);
      const width = (300 - 2 * 8) / 3;
      expect(a.width, closeTo(width, 0.5));
      expect(b.width, closeTo(width, 0.5));
      expect(c.width, closeTo(width, 0.5));
      expect(a.left, closeTo(0, 0.5));
      expect(b.left - a.right, closeTo(8, 0.5));
      expect(c.right, closeTo(300, 0.5));
      // The first column's text starts at the start edge, the last column's
      // text ends on the end edge, the middle one starts at its own start.
      expect(tester.getTopLeft(find.text('out')).dx, closeTo(0, 0.5));
      expect(tester.getTopRight(find.text('9.5%')).dx, closeTo(300, 0.5));
      expect(tester.getTopRight(find.text('XIRR')).dx, closeTo(300, 0.5));
      expect(tester.getTopLeft(find.text('in')).dx, closeTo(b.left, 0.5));
    });

    testWidgets('mirrors in a right-to-left layout', (tester) async {
      await tester.pumpWidget(
        _app(
          direction: TextDirection.rtl,
          child: StatColumns(
            columns: [
              _col('out', '₹1'),
              _col('in', '₹22'),
              _col('XIRR', '9.5%'),
            ],
          ),
        ),
      );

      // The first column is at the right, the last ends on the left edge.
      expect(_cell(tester, 0).right, closeTo(300, 0.5));
      expect(_cell(tester, 2).left, closeTo(0, 0.5));
      expect(tester.getTopRight(find.text('out')).dx, closeTo(300, 0.5));
      expect(tester.getTopLeft(find.text('9.5%')).dx, closeTo(0, 0.5));
    });
  });

  testWidgets('centre alignment centres every column', (tester) async {
    await tester.pumpWidget(
      _app(
        child: StatColumns(
          align: StatColumnsAlign.center,
          columns: [
            _col('XIRR', '9.5%'),
            _col('MOIC', '1.4x', note: '1.9y'),
          ],
        ),
      ),
    );

    for (var i = 0; i < 2; i++) {
      final cell = _cell(tester, i);
      expect(
        tester.getCenter(find.text(['9.5%', '1.4x'][i])).dx,
        closeTo(cell.center.dx, 0.5),
      );
    }
    expect(
      tester.getCenter(find.text('1.9y')).dx,
      closeTo(_cell(tester, 1).center.dx, 0.5),
    );
  });

  group('one baseline', () {
    final columns = [
      // A label that wraps to many lines and a larger value ...
      _col('A very long label that wraps over lines', 'AAAA', valueSize: 14),
      // ... next to a one-line label, a different value size and a note.
      _col('Short', 'BBBB', valueSize: 16, note: 'a note'),
    ];

    testWidgets('values share it when a label wraps and sizes differ', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          width: 200,
          child: StatColumns(align: StatColumnsAlign.center, columns: columns),
        ),
      );

      expect(
        baselineY(tester, find.text('AAAA')),
        closeTo(baselineY(tester, find.text('BBBB')), 0.5),
      );
      // The extra label lines grew upward and the note sits below its value.
      final label = tester.getRect(
        find.text('A very long label that wraps over lines'),
      );
      expect(
        label.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text('AAAA')).dy),
      );
      expect(
        tester.getTopLeft(find.text('a note')).dy,
        greaterThanOrEqualTo(tester.getRect(find.text('BBBB')).bottom),
      );
    });

    testWidgets('labels share one too, whatever the sizes of the values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: StatColumns(
            columns: [
              _col('out', '₹1', valueSize: 14),
              _col('in', '₹22', valueSize: 14),
              _col('XIRR', '9.5%', valueSize: 20),
            ],
          ),
        ),
      );

      // The values sit on one baseline although the XIRR is larger ...
      final base = baselineY(tester, find.text('₹1'));
      expect(baselineY(tester, find.text('₹22')), closeTo(base, 0.5));
      expect(baselineY(tester, find.text('9.5%')), closeTo(base, 0.5));
      // ... and so do the labels above them.
      final label = baselineY(tester, find.text('out'));
      expect(baselineY(tester, find.text('in')), closeTo(label, 0.5));
      expect(baselineY(tester, find.text('XIRR')), closeTo(label, 0.5));
    });

    testWidgets('the value key has the width of the column', (tester) async {
      await tester.pumpWidget(
        _app(
          child: StatColumns(columns: [_col('out', '₹1'), _col('in', '₹22')]),
        ),
      );

      for (var i = 0; i < 2; i++) {
        final value = tester.getRect(find.byKey(StatColumns.valueKey(i)));
        expect(value.width, closeTo(_cell(tester, i).width, 0.5));
        expect(value.left, closeTo(_cell(tester, i).left, 0.5));
      }
    });

    testWidgets('a note on one column does not move the other value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: StatColumns(
            align: StatColumnsAlign.center,
            columns: [
              _col('XIRR', '9.5%'),
              _col('MOIC', '1.4x', note: '1.9y'),
            ],
          ),
        ),
      );
      expect(
        baselineY(tester, find.text('9.5%')),
        closeTo(baselineY(tester, find.text('1.4x')), 0.5),
      );
    });
  });

  testWidgets('tiles share a top and a height', (tester) async {
    await tester.pumpWidget(
      _app(
        child: StatColumns(
          align: StatColumnsAlign.center,
          gap: 10,
          tileBuilder: (context, i) =>
              Container(key: ValueKey('tile-$i'), color: Colors.grey),
          tilePadding: const EdgeInsets.all(12),
          columns: [
            _col('XIRR', '9.5%'),
            _col('MOIC', '1.4x', note: '1.9y'),
          ],
        ),
      ),
    );

    final a = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final b = tester.getRect(find.byKey(const ValueKey('tile-1')));
    expect(a.top, closeTo(b.top, 0.5));
    expect(a.height, closeTo(b.height, 0.5));
    expect(a.width, closeTo((300 - 10) / 2, 0.5));
    expect(b.left - a.right, closeTo(10, 0.5));
    // The content is inset by the tile padding and the tile holds it.
    final value = tester.getRect(find.text('9.5%'));
    expect(value.top, greaterThanOrEqualTo(a.top + 12));
    final note = tester.getRect(find.text('1.9y'));
    expect(note.bottom, lessThanOrEqualTo(b.bottom - 12 + 0.01));
  });

  group('stacking', () {
    final four = [
      _col('out', '₹1'),
      _col('in', '₹22'),
      _col('Expected XIRR', '8.7%'),
      _col('Realised XIRR', '12.0%'),
    ];

    testWidgets('a lone last column is a row of label and value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(width: 288, child: StatColumns(columns: four, minColumnWidth: 72)),
      );

      final row = _cell(tester, 3);
      expect(row.width, closeTo(288, 0.5));
      expect(row.top, greaterThan(_cell(tester, 0).bottom - 0.01));
      // Label on the start edge, value on the end edge, one baseline.
      expect(tester.getTopLeft(find.text('Realised XIRR')).dx, closeTo(0, 0.5));
      expect(tester.getTopRight(find.text('12.0%')).dx, closeTo(288, 0.5));
      expect(
        baselineY(tester, find.text('Realised XIRR')),
        closeTo(baselineY(tester, find.text('12.0%')), 0.5),
      );
      // The first row keeps three columns, with the XIRR on the end.
      expect(_cell(tester, 2).right, closeTo(288, 0.5));
    });

    testWidgets('large text drops to two columns, then to one', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 288,
          textScale: 1.3,
          child: StatColumns(columns: four, minColumnWidth: 72),
        ),
      );
      // Two per row: out and in, then the two XIRRs.
      expect(_cell(tester, 0).top, closeTo(_cell(tester, 1).top, 0.5));
      expect(_cell(tester, 2).top, greaterThan(_cell(tester, 1).bottom - 0.01));
      expect(_cell(tester, 2).top, closeTo(_cell(tester, 3).top, 0.5));
      expect(_cell(tester, 3).right, closeTo(288, 0.5));

      await tester.pumpWidget(
        _app(
          width: 288,
          textScale: 2.0,
          child: StatColumns(columns: four, minColumnWidth: 72),
        ),
      );
      for (var i = 0; i < 4; i++) {
        expect(_cell(tester, i).width, closeTo(288, 0.5));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a minimum width the columns never stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          width: 150,
          textScale: 2.0,
          child: StatColumns(
            columns: [_col('a', '1'), _col('b', '2'), _col('c', '3')],
          ),
        ),
      );
      expect(_cell(tester, 0).top, closeTo(_cell(tester, 2).top, 0.5));
    });
  });

  group('semantics', () {
    testWidgets('a column reads label, value, then note, left to right', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: StatColumns(
            align: StatColumnsAlign.center,
            columns: [
              _col('XIRR label', '9.5%', note: 'xirr note'),
              _col('MOIC label', '1.4x', note: 'moic note'),
            ],
          ),
        ),
      );

      final order = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .where((l) => l.isNotEmpty)
          .toList();
      expect(order, [
        'XIRR label',
        '9.5%',
        'xirr note',
        'MOIC label',
        '1.4x',
        'moic note',
      ]);
      handle.dispose();
    });

    testWidgets('a semantics label replaces the texts of its column', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: StatColumns(
            columns: [
              _col('XIRR', '9.5%', semanticsLabel: 'XIRR: 9.5 percent'),
              _col('MOIC', '1.4x'),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('XIRR: 9.5 percent'), findsOneWidget);
      expect(find.bySemanticsLabel('XIRR'), findsNothing);
      expect(find.bySemanticsLabel('9.5%'), findsNothing);
      expect(find.bySemanticsLabel('MOIC'), findsOneWidget);
      handle.dispose();
    });
  });
}
