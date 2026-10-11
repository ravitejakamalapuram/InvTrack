/// A53: the shipped app icon is the "Portfolio ring" and nothing else.
///
/// These are file checks (no widgets): they decode the PNGs and read the
/// Android resources and pubspec as text, so they run on a bare checkout. Each
/// group names the defect it guards:
///
/// - the old `app_icon.png` carried a grey sparkle (#888998) in its bottom-right
///   corner that looked like an image-generator watermark;
/// - the same file is opaque, so the lock screen's white `srcIn` tint painted a
///   solid square instead of the mark;
/// - the adaptive icon had no monochrome layer (Android 13 themed icons) and a
///   16% inset that shrank the art;
/// - the lock screen's asset was not declared under `flutter: assets:` in the
///   pubspec, so the real app showed the fallback shield, not the logo.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _iconDir = 'assets/icons';
const _res = 'android/app/src/main/res';
const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

/// The adaptive-icon canvas is 108 units; the safe zone is the central 66.
const _canvas = 108.0;
const _safeSquare = 66.0;

/// A decoded PNG: straight (not premultiplied) RGBA, row-major.
class _Png {
  _Png(this.width, this.height, this.rgba, this.colorType, this.bitDepth);

  final int width;
  final int height;
  final Uint8List rgba;

  /// IHDR colour type: 2 = RGB, 3 = palette, 6 = RGBA.
  final int colorType;
  final int bitDepth;

  int _at(int x, int y) => (y * width + x) * 4;
  int red(int x, int y) => rgba[_at(x, y)];
  int green(int x, int y) => rgba[_at(x, y) + 1];
  int blue(int x, int y) => rgba[_at(x, y) + 2];
  int alpha(int x, int y) => rgba[_at(x, y) + 3];

  /// Pixels whose alpha is above [min].
  int countVisible({int min = 0}) {
    var n = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] > min) n++;
    }
    return n;
  }

  Iterable<(int, int)> get corners => [
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
  ];
}

final _decoded = <String, Future<_Png>>{};

Future<_Png> _png(String path) => _decoded.putIfAbsent(path, () async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  final bytes = file.readAsBytesSync();
  // IHDR: signature (8) + length/type (8) + width, height (8) + depth, type.
  expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47], reason: '$path is not a PNG');
  final bitDepth = bytes[24];
  final colorType = bytes[25];
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final png = _Png(
    image.width,
    image.height,
    data!.buffer.asUint8List(),
    colorType,
    bitDepth,
  );
  image.dispose();
  codec.dispose();
  return png;
});

double _dist(int r1, int g1, int b1, int r2, int g2, int b2) =>
    sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2));

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

String _read(String path) => File(path).readAsStringSync();

/// The lines of the top-level pubspec block [key] (without the key line).
List<String> _pubspecBlock(String key) {
  final lines = _read('pubspec.yaml').split('\n');
  final start = lines.indexWhere((l) => l.trimRight() == '$key:');
  expect(start, isNot(-1), reason: 'pubspec.yaml has no "$key:" block');
  final block = <String>[];
  for (final line in lines.skip(start + 1)) {
    final topLevel =
        line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#');
    if (topLevel) break;
    block.add(line);
  }
  return block;
}

/// `key: "value"` pairs of the flutter_launcher_icons block (any depth).
Map<String, List<String>> _launcherIconConfig() {
  final config = <String, List<String>>{};
  for (final line in _pubspecBlock('flutter_launcher_icons')) {
    final m = RegExp(
      r'^\s*(\w+):\s*(?:"([^"]*)"|([^\s#"]+))\s*(?:#.*)?$',
    ).firstMatch(line);
    if (m == null) continue;
    config.putIfAbsent(m.group(1)!, () => []).add(m.group(2) ?? m.group(3)!);
  }
  return config;
}

/// Entries under `flutter: assets:` in the pubspec.
List<String> _declaredAssets() {
  final entries = <String>[];
  var inAssets = false;
  for (final line in _pubspecBlock('flutter')) {
    if (RegExp(r'^  assets:\s*$').hasMatch(line)) {
      inAssets = true;
      continue;
    }
    if (inAssets && RegExp(r'^  \S').hasMatch(line)) inAssets = false;
    final m = RegExp(r'^\s{4}-\s+(\S+)\s*$').firstMatch(line);
    if (inAssets && m != null) entries.add(m.group(1)!);
  }
  return entries;
}

/// Android colour resource [name] in `values*/colors.xml`, upper case.
String? _androidColor(String valuesDir, String name) {
  final m = RegExp(
    '<color name="$name">(#[0-9A-Fa-f]{6,8})</color>',
  ).firstMatch(_read('$_res/$valuesDir/colors.xml'));
  return m?.group(1)!.toUpperCase();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('source art', () {
    for (final name in [
      'app_icon.svg',
      'app_icon_foreground.svg',
      'app_icon_monochrome.svg',
    ]) {
      test('$name is the 108-unit Portfolio ring source and stays tiny', () {
        final file = File('$_iconDir/$name');
        expect(file.existsSync(), isTrue, reason: '$name is missing');
        final svg = file.readAsStringSync();
        expect(file.lengthSync(), lessThan(4096), reason: '$name too big');
        expect(svg, contains('viewBox="0 0 108 108"'));
      });
    }

    test('monochrome source uses one colour only', () {
      final svg = _read('$_iconDir/app_icon_monochrome.svg');
      final colours = RegExp(
        r'(?:fill|stroke)="(#[0-9A-Fa-f]{3,8})"',
      ).allMatches(svg).map((m) => m.group(1)!.toUpperCase()).toSet();
      expect(colours, {'#000000'});
      expect(svg, isNot(contains('url(#')), reason: 'no gradients');
    });
  });

  group('app_icon.png (launcher, iOS and web source)', () {
    test('is 1024x1024 and fully opaque', () async {
      final p = await _png('$_iconDir/app_icon.png');
      expect((p.width, p.height), (1024, 1024));
      var translucent = 0;
      for (var i = 3; i < p.rgba.length; i += 4) {
        if (p.rgba[i] != 255) translucent++;
      }
      expect(translucent, 0, reason: 'pixels with alpha below 255');
    });

    test('has no watermark in its bottom-right corner', () async {
      final p = await _png('$_iconDir/app_icon.png');
      expect(
        await _watermarkPixels(p),
        isEmpty,
        reason: 'pixels that look like a corner watermark',
      );
    });

    test(
      'shows the ring: violet segments, a green slice, dark ground',
      () async {
        final p = await _png('$_iconDir/app_icon.png');
        var violet = 0;
        var green = 0;
        for (var y = 0; y < p.height; y += 2) {
          for (var x = 0; x < p.width; x += 2) {
            final r = p.red(x, y), g = p.green(x, y), b = p.blue(x, y);
            if (g > r + 60 && g > b + 40) green++;
            if (b > 200 && b > g + 40 && r > 90) violet++;
          }
        }
        expect(green, greaterThan(1500), reason: 'green slice pixels');
        expect(violet, greaterThan(3000), reason: 'violet segment pixels');
        for (final (x, y) in p.corners) {
          expect(
            p.red(x, y) + p.green(x, y) + p.blue(x, y),
            lessThan(150),
            reason: 'corner ($x, $y) should be the dark ground',
          );
        }
      },
    );
  });

  group('play_store_512.png (for the owner to upload)', () {
    test('is 512x512, 32-bit RGBA and fully opaque', () async {
      final p = await _png('$_iconDir/play_store_512.png');
      expect((p.width, p.height), (512, 512));
      expect((p.bitDepth, p.colorType), (8, 6), reason: '32-bit RGBA');
      expect(p.countVisible(min: 254), 512 * 512, reason: 'opaque pixels');
    });

    test('has no watermark and the same ring as app_icon.png', () async {
      final p = await _png('$_iconDir/play_store_512.png');
      expect(await _watermarkPixels(p), isEmpty);
      final big = await _png('$_iconDir/app_icon.png');
      // Compare the centre pixel of each green-ish slice location: sample a
      // 16 x 16 grid and require nearly every sample to agree within 12.
      var close = 0;
      for (var j = 0; j < 16; j++) {
        for (var i = 0; i < 16; i++) {
          final x = 16 + i * 32, y = 16 + j * 32;
          final d = _dist(
            p.red(x, y),
            p.green(x, y),
            p.blue(x, y),
            big.red(x * 2, y * 2),
            big.green(x * 2, y * 2),
            big.blue(x * 2, y * 2),
          );
          if (d < 12) close++;
        }
      }
      expect(close, greaterThan(240), reason: 'samples matching app_icon.png');
    });
  });

  group('app_icon_mark.png (lock screen, tinted with srcIn)', () {
    test('has fully transparent corners', () async {
      final p = await _png('$_iconDir/app_icon_mark.png');
      for (final (x, y) in p.corners) {
        expect(p.alpha(x, y), 0, reason: 'corner ($x, $y) alpha');
      }
    });

    test('is a mark, not a square: 12% to 60% of pixels are drawn', () async {
      final p = await _png('$_iconDir/app_icon_mark.png');
      final share = p.countVisible() / (p.width * p.height);
      expect(share, greaterThanOrEqualTo(0.12), reason: 'too little drawn');
      expect(share, lessThanOrEqualTo(0.60), reason: 'looks like a square');
    });
  });

  group('app_icon_monochrome.png (Android 13 themed icon)', () {
    test('every drawn pixel has the same colour and some are drawn', () async {
      final p = await _png('$_iconDir/app_icon_monochrome.png');
      final colours = <int>{};
      for (var i = 0; i < p.rgba.length; i += 4) {
        if (p.rgba[i + 3] == 0) continue;
        colours.add((p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2]);
      }
      expect(p.countVisible(), greaterThan(0), reason: 'nothing drawn');
      expect(colours.length, 1, reason: 'RGB values of drawn pixels: $colours');
      for (final (x, y) in p.corners) {
        expect(p.alpha(x, y), 0, reason: 'corner ($x, $y) alpha');
      }
    });

    test('has the same size as the foreground layer', () async {
      final mono = await _png('$_iconDir/app_icon_monochrome.png');
      final fg = await _png('$_iconDir/app_icon_foreground.png');
      expect((mono.width, mono.height), (fg.width, fg.height));
    });
  });

  group('app_icon_foreground.png (adaptive icon layer)', () {
    test('has transparent corners', () async {
      final p = await _png('$_iconDir/app_icon_foreground.png');
      expect(p.width, p.height, reason: 'square canvas');
      for (final (x, y) in p.corners) {
        expect(p.alpha(x, y), 0, reason: 'corner ($x, $y) alpha');
      }
    });

    // Launchers mask the layer with a circle, a squircle or a rounded square.
    // The circle is the strictest, with a radius of 33 of the 108 units.
    for (final name in ['app_icon_foreground.png', 'app_icon_monochrome.png']) {
      test('$name draws only inside the circular safe zone', () async {
        final p = await _png('$_iconDir/$name');
        expect(p.countVisible(), greaterThan(0), reason: 'nothing drawn');
        final unit = p.width / _canvas;
        // One unit of tolerance for anti-aliasing at the edge of the zone.
        final limit = _safeSquare / 2 + 1;
        final outside = <String>[];
        for (var y = 0; y < p.height; y++) {
          for (var x = 0; x < p.width; x++) {
            if (p.alpha(x, y) <= 8) continue;
            final dx = (x + 0.5) / unit - _canvas / 2;
            final dy = (y + 0.5) / unit - _canvas / 2;
            if (dx * dx + dy * dy > limit * limit && outside.length < 5) {
              outside.add(
                '(${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)})',
              );
            }
          }
        }
        expect(
          outside,
          isEmpty,
          reason: 'drawn outside the safe circle (units from centre)',
        );
      });
    }
  });

  group('Android adaptive icon resources', () {
    final xml = File('$_res/mipmap-anydpi-v26/ic_launcher.xml');

    test('has background, foreground and a monochrome layer', () {
      final text = xml.readAsStringSync();
      expect(text, contains('<background'));
      expect(text, contains('<foreground'));
      expect(text, contains('<monochrome'), reason: 'Android 13 themed icon');
    });

    test('does not inset (shrink) the foreground or monochrome art', () {
      final text = xml.readAsStringSync();
      final insets = RegExp(
        r'android:inset="(\d+)%"',
      ).allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
      expect(insets.where((v) => v != 0), isEmpty, reason: 'insets: $insets');
    });

    test('every drawable it references exists in every density', () {
      final text = xml.readAsStringSync();
      final drawables = RegExp(
        r'@drawable/(\w+)',
      ).allMatches(text).map((m) => m.group(1)!).toSet();
      expect(
        drawables,
        containsAll(['ic_launcher_foreground', 'ic_launcher_monochrome']),
      );
      for (final name in drawables) {
        for (final d in _densities) {
          final f = File('$_res/drawable-$d/$name.png');
          expect(f.existsSync(), isTrue, reason: '${f.path} is missing');
        }
      }
      for (final d in _densities) {
        final f = File('$_res/mipmap-$d/ic_launcher.png');
        expect(f.existsSync(), isTrue, reason: '${f.path} is missing');
      }
    });

    test('the background colour it references is the ring ground', () {
      final text = xml.readAsStringSync();
      expect(text, contains('@color/ic_launcher_background'));
      expect(_androidColor('values', 'ic_launcher_background'), '#1A1A2E');
      expect(
        _androidColor('values-night', 'ic_launcher_background'),
        '#1A1A2E',
      );
    });
  });

  group('pubspec flutter_launcher_icons', () {
    test('every PNG path it names exists', () {
      final config = _launcherIconConfig();
      final paths = config.values
          .expand((v) => v)
          .where((v) => v.endsWith('.png'))
          .toSet();
      expect(paths, isNotEmpty);
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('uses the transparent foreground, monochrome layer and no inset', () {
      final config = _launcherIconConfig();
      expect(config['image_path']!.first, '$_iconDir/app_icon.png');
      expect(config['adaptive_icon_foreground'], [
        '$_iconDir/app_icon_foreground.png',
      ]);
      expect(config['adaptive_icon_monochrome'], [
        '$_iconDir/app_icon_monochrome.png',
      ]);
      expect(config['adaptive_icon_foreground_inset'], ['0']);
    });

    test('adaptive_icon_background equals ic_launcher_background', () {
      final config = _launcherIconConfig();
      expect(
        config['adaptive_icon_background']!.single.toUpperCase(),
        _androidColor('values', 'ic_launcher_background'),
      );
    });
  });

  group('lock screen mark', () {
    final wrapper = _read(
      'lib/features/security/presentation/widgets/'
      'privacy_protection_wrapper.dart',
    );
    final assets = RegExp(
      r"'(assets/[^']+)'",
    ).allMatches(wrapper).map((m) => m.group(1)!).toSet();

    test('the wrapper draws the transparent mark, not the opaque icon', () {
      expect(assets, {'$_iconDir/app_icon_mark.png'});
    });

    test('every asset the wrapper references exists and is declared', () {
      final declared = _declaredAssets();
      expect(assets, isNotEmpty);
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
        final covered = declared.any(
          (d) => d == asset || (d.endsWith('/') && asset.startsWith(d)),
        );
        expect(
          covered,
          isTrue,
          reason:
              '$asset is not under flutter: assets: in pubspec.yaml '
              '(declared: $declared), so the app falls back to the shield',
        );
      }
    });
  });
}

/// Pixels in the bottom-right 15% square of [p] that look like a watermark:
/// near the old sparkle grey (#888998), or off the local background.
///
/// The local background is the median colour of that square: a smooth ground
/// gradient moves by only a few levels across it, whereas a mark covers a
/// minority of its pixels and differs by a lot.
Future<List<String>> _watermarkPixels(_Png p) async {
  final x0 = (p.width * 0.85).floor(), y0 = (p.height * 0.85).floor();
  final reds = <int>[], greens = <int>[], blues = <int>[];
  for (var y = y0; y < p.height; y++) {
    for (var x = x0; x < p.width; x++) {
      reds.add(p.red(x, y));
      greens.add(p.green(x, y));
      blues.add(p.blue(x, y));
    }
  }
  final bg = (_median(reds), _median(greens), _median(blues));
  final bad = <String>[];
  var count = 0;
  for (var y = y0; y < p.height; y++) {
    for (var x = x0; x < p.width; x++) {
      final r = p.red(x, y), g = p.green(x, y), b = p.blue(x, y);
      final nearGrey = _dist(r, g, b, 0x88, 0x89, 0x98) < 30;
      final offBackground =
          (r - bg.$1).abs() > 8 ||
          (g - bg.$2).abs() > 8 ||
          (b - bg.$3).abs() > 8;
      if (nearGrey || offBackground) {
        count++;
        if (bad.length < 3) bad.add('($x, $y) rgb($r, $g, $b)');
      }
    }
  }
  if (count > 0) bad.add('$count pixels in total');
  return bad;
}
