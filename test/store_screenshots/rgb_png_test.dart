// The Play listing check wants 24-bit PNGs with no alpha channel
// (docs/UPDATE_STORE_LISTING.md), but the engine only writes RGBA. The
// encoder must therefore produce colour type 2 and keep the pixels intact.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'rgb_png.dart';

Future<Uint8List> _decodeToRgba(WidgetTester tester, Uint8List png) async {
  late Uint8List rgba;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    rgba = data!.buffer.asUint8List();
  });
  return rgba;
}

Uint8List _pixels(List<List<int>> rgbaPixels) =>
    Uint8List.fromList([for (final pixel in rgbaPixels) ...pixel]);

void main() {
  testWidgets('encodes colour type 2 (RGB, 8 bit, no alpha) and keeps pixels', (
    tester,
  ) async {
    final rgba = _pixels([
      [255, 0, 0, 255], [0, 255, 0, 255], //
      [0, 0, 255, 255], [18, 52, 86, 255],
    ]);

    final png = encodeRgbPng(2, 2, rgba);

    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(png);
    expect(header.getUint32(16), 2, reason: 'width');
    expect(header.getUint32(20), 2, reason: 'height');
    expect(png[24], 8, reason: 'bit depth');
    expect(png[25], 2, reason: 'colour type 2 = RGB without alpha');
    expect(await _decodeToRgba(tester, png), rgba);
  });

  testWidgets('composites transparent pixels over white, not black', (
    tester,
  ) async {
    final rgba = _pixels([
      [0, 0, 0, 0], [0, 0, 0, 255], //
      [0, 0, 0, 255], [0, 0, 0, 0],
    ]);

    final decoded = await _decodeToRgba(tester, encodeRgbPng(2, 2, rgba));

    expect(decoded.sublist(0, 4), [255, 255, 255, 255]);
    expect(decoded.sublist(4, 8), [0, 0, 0, 255]);
  });

  testWidgets('a full-size frame encodes and decodes at 1080x1920', (
    tester,
  ) async {
    final rgba = Uint8List(1080 * 1920 * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = (i >> 8) & 0xff;
      rgba[i + 1] = (i >> 12) & 0xff;
      rgba[i + 2] = 0x5b;
      rgba[i + 3] = 0xff;
    }

    final png = encodeRgbPng(1080, 1920, rgba);

    expect(ByteData.sublistView(png).getUint32(16), 1080);
    expect(ByteData.sublistView(png).getUint32(20), 1920);
    expect(await _decodeToRgba(tester, png), rgba);
  });

  test('rejects a buffer that does not match the size', () {
    expect(
      () => encodeRgbPng(2, 2, Uint8List(15)),
      throwsA(isA<ArgumentError>()),
    );
  });
}
