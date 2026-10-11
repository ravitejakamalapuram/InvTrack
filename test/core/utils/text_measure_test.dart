import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/text_measure.dart';

/// Reads [measureTextWidth] under the given text settings. The test font
/// (Ahem) draws every glyph as a square of the font size.
Future<double> _measure(
  WidgetTester tester,
  String text,
  TextStyle style, {
  TextScaler scaler = TextScaler.noScaling,
  bool boldText = false,
  TextStyle defaults = const TextStyle(fontSize: 10),
  TextDirection direction = TextDirection.ltr,
}) async {
  late double width;
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQueryData(textScaler: scaler, boldText: boldText),
        child: DefaultTextStyle(
          style: defaults,
          child: Builder(
            builder: (context) {
              width = measureTextWidth(context, text, style);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return width;
}

void main() {
  testWidgets('is the width of the text on one line in its style', (
    tester,
  ) async {
    expect(
      await _measure(tester, 'abcd', const TextStyle(fontSize: 14)),
      closeTo(56, 0.01),
    );
  });

  testWidgets('takes the inherited style where the style says nothing', (
    tester,
  ) async {
    expect(
      await _measure(tester, 'abcd', const TextStyle()),
      closeTo(40, 0.01),
    );
  });

  testWidgets('grows with the text scaler like a Text does', (tester) async {
    expect(
      await _measure(
        tester,
        'abcd',
        const TextStyle(fontSize: 14),
        scaler: const TextScaler.linear(2),
      ),
      closeTo(112, 0.01),
    );
  });

  testWidgets('is the same in both reading directions', (tester) async {
    const style = TextStyle(fontSize: 14);
    final ltr = await _measure(tester, 'abcd', style);
    final rtl = await _measure(
      tester,
      'abcd',
      style,
      direction: TextDirection.rtl,
    );
    expect(rtl, ltr);
  });

  testWidgets('measures the line, not a wrapped part of it', (tester) async {
    expect(
      await _measure(tester, 'ab cd ef', const TextStyle(fontSize: 10)),
      closeTo(80, 0.01),
    );
  });
}
