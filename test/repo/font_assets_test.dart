/// #973: every font the pubspec bundles is a real font file.
///
/// The four Plus Jakarta Sans files were once GitHub "Page not found" HTML
/// pages saved under a .ttf name, so offline headlines silently fell back to
/// the system font. This reads each declared asset's first bytes and checks
/// for a TrueType or OpenType signature.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final assets = RegExp(r'- asset: (assets/fonts/\S+)')
      .allMatches(File('pubspec.yaml').readAsStringSync())
      .map((m) => m.group(1)!)
      .toList();

  test('the pubspec declares bundled fonts', () {
    expect(assets, isNotEmpty);
  });

  for (final path in assets) {
    test('$path is a TrueType or OpenType font', () {
      final head = File(path).openSync().readSync(4);
      final isTrueType =
          head.length == 4 &&
          head[0] == 0 &&
          head[1] == 1 &&
          head[2] == 0 &&
          head[3] == 0;
      final isOpenType = String.fromCharCodes(head) == 'OTTO';
      expect(isTrueType || isOpenType, isTrue, reason: '$path is not a font');
    });
  }
}
