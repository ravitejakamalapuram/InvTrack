// CardFooterRow: the leading status keeps its natural width and the trailing
// text is right-aligned (end-aligned) to the row's end edge, wrapping instead of
// being cut. The test font (Ahem) makes every glyph a square of the font size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/card_footer_row.dart';

import '../../helpers/text_geometry.dart';

Widget _app({
  required String trailing,
  String leading = 'Achieved',
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
        child: SizedBox(
          width: width,
          child: CardFooterRow(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 14),
                const SizedBox(width: 6),
                Text(leading, style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailingText: trailing,
            trailingStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('short text ends on the end edge, not half way', (tester) async {
    await tester.pumpWidget(_app(trailing: 'Done!'));

    expect(glyphRect(tester, find.text('Done!')).right, closeTo(300, 0.5));
    expect(glyphRect(tester, find.text('Achieved')).left, closeTo(20, 0.5));
  });

  testWidgets('every length ends on the same edge', (tester) async {
    for (final text in [
      'Done!',
      'Goal achieved!',
      'On track for Jun 2057',
      'Ahead of schedule!',
    ]) {
      await tester.pumpWidget(_app(trailing: text));
      expect(glyphRect(tester, find.text(text)).right, closeTo(300, 0.5));
    }
  });

  testWidgets('long text wraps, ends on the end edge and is not cut', (
    tester,
  ) async {
    const text = 'Behind schedule needs attention soon';
    await tester.pumpWidget(_app(trailing: text, leading: 'Behind'));

    final widget = tester.widget<Text>(find.text(text));
    expect(widget.maxLines, isNull);
    expect(widget.overflow, isNull);
    expect(widget.textAlign, TextAlign.end);
    final glyphs = glyphRect(tester, find.text(text));
    expect(glyphs.right, closeTo(300, 0.5));
    expect(glyphs.height, greaterThan(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first line shares a baseline with the status', (
    tester,
  ) async {
    await tester.pumpWidget(_app(trailing: 'Goal achieved!'));

    // Same font size: the same top is the same baseline in Ahem.
    expect(
      glyphRect(tester, find.text('Goal achieved!')).top,
      closeTo(glyphRect(tester, find.text('Achieved')).top, 0.5),
    );
  });

  testWidgets('an empty trailing text draws nothing', (tester) async {
    await tester.pumpWidget(_app(trailing: ''));

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('Achieved'), findsOneWidget);
  });

  testWidgets('mirrors in a right-to-left layout', (tester) async {
    await tester.pumpWidget(
      _app(trailing: 'Goal achieved!', direction: TextDirection.rtl),
    );

    expect(
      glyphRect(tester, find.text('Goal achieved!')).left,
      closeTo(0, 0.5),
    );
    expect(glyphRect(tester, find.text('Achieved')).right, closeTo(280, 0.5));
  });

  testWidgets('a long status does not overflow at 2x text', (tester) async {
    await tester.pumpWidget(
      _app(
        trailing: 'Behind schedule - needs attention',
        leading: 'Behind',
        width: 260,
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      glyphRect(tester, find.text('Behind schedule - needs attention')).right,
      closeTo(260, 0.5),
    );
  });
}
