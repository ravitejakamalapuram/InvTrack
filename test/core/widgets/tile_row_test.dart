// TileRow: tiles side by side with equal widths that share a top and a height.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/tile_row.dart';

Widget _app({
  required List<Widget> children,
  double width = 300,
  double gap = 12,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    builder: (context, app) =>
        Directionality(textDirection: direction, child: app!),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: TileRow(gap: gap, children: children),
        ),
      ),
    ),
  );
}

Widget _tile(String key, {int lines = 1}) => Container(
  key: ValueKey(key),
  color: Colors.grey,
  // As tall as its lines and no taller: whatever makes two tiles equal is the
  // row, not the tile.
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (var i = 0; i < lines; i++) Text('line $i')],
  ),
);

void main() {
  testWidgets(
    'tiles with a different number of lines share a top and a height',
    (tester) async {
      await tester.pumpWidget(
        _app(children: [_tile('a', lines: 3), _tile('b', lines: 1)]),
      );

      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      expect(b.top, closeTo(a.top, 0.01));
      expect(b.height, closeTo(a.height, 0.01));
      // The tallest tile sets the height: three lines of 14px test text.
      expect(a.height, greaterThanOrEqualTo(3 * 14));
    },
  );

  testWidgets('equal widths with the gap between', (tester) async {
    await tester.pumpWidget(
      _app(children: [_tile('a'), _tile('b'), _tile('c')], gap: 10),
    );

    final rects = [
      for (final k in ['a', 'b', 'c']) tester.getRect(find.byKey(ValueKey(k))),
    ];
    for (final r in rects) {
      expect(r.width, closeTo((300 - 20) / 3, 0.01));
    }
    expect(rects[1].left - rects[0].right, closeTo(10, 0.01));
    expect(rects[2].left - rects[1].right, closeTo(10, 0.01));
    expect(rects[2].right, closeTo(300, 0.01));
  });

  testWidgets('the first tile is on the start edge in right to left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(children: [_tile('a'), _tile('b')], direction: TextDirection.rtl),
    );

    final a = tester.getRect(find.byKey(const ValueKey('a')));
    final b = tester.getRect(find.byKey(const ValueKey('b')));
    expect(a.right, closeTo(300, 0.01));
    expect(b.left, closeTo(0, 0.01));
  });
}
