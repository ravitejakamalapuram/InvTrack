import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/text_scale.dart';

/// Reads [textScaleOf] under [scaler].
Future<double> _read(WidgetTester tester, TextScaler scaler) async {
  late double scale;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: scaler),
      child: Builder(
        builder: (context) {
          scale = textScaleOf(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return scale;
}

void main() {
  testWidgets('is the factor of a linear text scaler', (tester) async {
    expect(await _read(tester, TextScaler.noScaling), closeTo(1.0, 1e-9));
    expect(
      await _read(tester, const TextScaler.linear(1.3)),
      closeTo(1.3, 1e-9),
    );
    expect(
      await _read(tester, const TextScaler.linear(2.0)),
      closeTo(2.0, 1e-9),
    );
  });

  testWidgets('follows a scaler that is not linear at body size', (
    tester,
  ) async {
    // Android 14 scales small text more than large text.
    final scaler = _Capped();
    expect(await _read(tester, scaler), closeTo(scaler.scale(14) / 14, 1e-9));
    expect(scaler.scale(14) / 14, isNot(closeTo(scaler.scale(40) / 40, 0.05)));
  });
}

/// Doubles up to 20sp, adds a flat 20sp above: not a linear factor.
class _Capped extends TextScaler {
  @override
  double scale(double fontSize) =>
      fontSize <= 20 ? fontSize * 2 : fontSize + 20;

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _Capped;

  @override
  int get hashCode => 1;
}
