import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The render object that draws [finder]: the finder's own text, else the first
/// text below it.
RenderParagraph paragraphOf(WidgetTester tester, Finder finder) {
  final inner = find.descendant(
    of: finder.first,
    matching: find.byType(RichText),
  );
  final target = inner.evaluate().isEmpty ? finder.first : inner.first;
  return tester.renderObject<RenderParagraph>(target);
}

/// The lines [paragraph] lays out, measured with a painter set up like its own
/// (the render object does not expose its line metrics).
List<ui.LineMetrics> paragraphLines(RenderParagraph paragraph) {
  final c = paragraph.constraints;
  final painter =
      TextPainter(
        text: paragraph.text,
        textAlign: paragraph.textAlign,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: paragraph.maxLines,
        ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
        locale: paragraph.locale,
        strutStyle: paragraph.strutStyle,
        textWidthBasis: paragraph.textWidthBasis,
        textHeightBehavior: paragraph.textHeightBehavior,
      )..layout(
        minWidth: c.minWidth,
        maxWidth:
            paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
            ? c.maxWidth
            : double.infinity,
      );
  final lines = painter.computeLineMetrics();
  painter.dispose();
  return lines;
}

/// y (screen) of the baseline of the first (or [last]) line of the text that
/// [finder] matches.
double baselineY(WidgetTester tester, Finder finder, {bool last = false}) {
  final paragraph = paragraphOf(tester, finder);
  final lines = paragraphLines(paragraph);
  final line = last ? lines.last : lines.first;
  return paragraph.localToGlobal(Offset.zero).dy + line.baseline;
}

/// The box (screen coordinates) that the glyphs of the first text matching
/// [finder] fill. A `Text` that fills its parent has a wider box than its
/// glyphs, which is what an alignment test must tell apart. The spaces are
/// left out: a space that ends a wrapped line hangs past the line's end.
Rect glyphRect(WidgetTester tester, Finder finder) {
  final paragraph = paragraphOf(tester, finder);
  final text = paragraph.text.toPlainText();
  Rect? rect;
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    for (final box in boxes) {
      rect = rect == null ? box.toRect() : rect.expandToInclude(box.toRect());
    }
  }
  return (rect ?? Rect.zero).shift(paragraph.localToGlobal(Offset.zero));
}
