import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';

import '../../integration_test/mocks/fake_fire_settings_repository.dart';
import '../../integration_test/mocks/store_demo_data.dart';
import '../../integration_test/test_app.dart';
import '../mocks/mock_currency_conversion_service.dart';
import 'rgb_png.dart';

const storeScreenshotsDirVar = 'STORE_SCREENSHOTS_DIR';
const storeScreenshotsEmojiFontVar = 'STORE_SCREENSHOTS_EMOJI_FONT';

/// Play phone screenshot size in physical pixels, and the pixel ratio that
/// makes it a 411.43 x 731.43 dp phone.
const storeScreenshotSize = Size(1080, 1920);
const _pixelRatio = 2.625;

/// A typical Android status bar, so SafeArea leaves the room it would on a
/// phone. Nothing is drawn there.
const _statusBarPx = 24 * _pixelRatio;

/// Where the PNGs are written; null renders and checks without writing.
String? get storeScreenshotsDir {
  final dir = Platform.environment[storeScreenshotsDirVar]?.trim();
  return dir == null || dir.isEmpty ? null : dir;
}

class StoreScreenshotFonts {
  const StoreScreenshotFonts({
    required this.fallbackFamilies,
    required this.testFontFamilies,
    required this.materialFontsFound,
    required this.emojiFontPath,
  });

  /// Families whose bundled font is unusable and that now use Roboto, as the
  /// platform default does on a device.
  final List<String> fallbackFamilies;

  /// Families that still render as solid test boxes.
  final List<String> testFontFamilies;

  /// Whether MaterialIcons (and Roboto) were found in the Flutter SDK cache.
  final bool materialFontsFound;

  /// The emoji font used for goal icons, or null when none was found.
  final String? emojiFontPath;
}

const _emojiFamily = 'NotoColorEmoji';

// google_fonts loads Inter and Plus Jakarta Sans lazily and asynchronously from
// assets/fonts. Ask for every weight the theme uses before the first frame, so
// no text is laid out in the test font.
const _interWeights = [FontWeight.w400, FontWeight.w500, FontWeight.w600];
const _jakartaWeights = [FontWeight.w600, FontWeight.w700, FontWeight.w800];

const _robotoFiles = [
  'Roboto-Regular.ttf',
  'Roboto-Medium.ttf',
  'Roboto-Bold.ttf',
  'Roboto-Black.ttf',
];

/// Loads every font the screens need. `flutter test` does not load the
/// pubspec fonts and has no system fallback, so anything not loaded here
/// would render as a solid box.
Future<StoreScreenshotFonts> loadStoreScreenshotFonts(
  WidgetTester tester,
) async {
  // Offline and deterministic: only fonts bundled with the app.
  GoogleFonts.config.allowRuntimeFetching = false;
  final appStyles = [
    for (final w in _interWeights)
      GoogleFonts.inter(fontSize: 20, fontWeight: w),
    for (final w in _jakartaWeights)
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: w),
  ];

  final materialFonts = _materialFontsDir();
  final emojiPath = _findEmojiFont();
  final fallback = <String>[];
  final stillTest = <String>[];

  await tester.runAsync(() async {
    if (materialFonts != null) {
      await _loadFamily('MaterialIcons', [
        File('$materialFonts/MaterialIcons-Regular.otf'),
      ]);
    }
    if (emojiPath != null) {
      await _loadFamily(_emojiFamily, [File(emojiPath)]);
    }
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // Reported by the check below, per family.
    }
    for (final style in appStyles) {
      final family = style.fontFamily!;
      if (!_rendersAsTestFont(style) || fallback.contains(family)) continue;
      if (materialFonts != null) {
        await _loadFamily(family, [
          for (final name in _robotoFiles) File('$materialFonts/$name'),
        ]);
        fallback.add(family);
      }
      if (_rendersAsTestFont(style)) stillTest.add(family);
    }
  });

  if (fallback.isNotEmpty) {
    debugPrint(
      'store screenshots: no usable font file for ${fallback.join(', ')}; '
      'using Roboto, which is what a device falls back to.',
    );
  }
  return StoreScreenshotFonts(
    fallbackFamilies: fallback,
    testFontFamilies: stillTest,
    materialFontsFound: materialFonts != null,
    emojiFontPath: emojiPath,
  );
}

Future<void> _loadFamily(String family, List<File> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// `<flutter>/bin/cache/artifacts/material_fonts`: MaterialIcons and Roboto.
String? _materialFontsDir() {
  final exe =
      Platform.resolvedExecutable; // <flutter>/bin/cache/.../flutter_tester
  final cache = exe.indexOf('/bin/cache/');
  final roots = [
    Platform.environment['FLUTTER_ROOT'],
    if (cache > 0) exe.substring(0, cache),
  ];
  for (final root in roots) {
    if (root == null) continue;
    final dir = '$root/bin/cache/artifacts/material_fonts';
    if (Directory(dir).existsSync()) return dir;
  }
  return null;
}

String? _findEmojiFont() {
  final candidates = [
    Platform.environment[storeScreenshotsEmojiFontVar],
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '/usr/share/fonts/noto/NotoColorEmoji.ttf',
    '/usr/share/fonts/google-noto-emoji/NotoColorEmoji.ttf',
    '/usr/share/fonts/google-noto-color-emoji-fonts/NotoColorEmoji.ttf',
  ];
  for (final path in candidates) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) return path;
  }
  return null;
}

final _measured = <String, bool>{};

/// True when [style] lays text out in the flutter_test font, where every
/// glyph is a square of the same width, instead of in a real font.
bool _rendersAsTestFont(TextStyle style) {
  double width(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  return (width('iiiiiiii') - width('mmmmmmmm')).abs() < 0.01;
}

/// No-op stand-ins for everything that needs a platform plugin or Firebase,
/// so the real app runs under `flutter test`.
List<Override> _storeOverrides(StoreDemoData demo) => [
  fireSettingsRepositoryProvider.overrideWithValue(
    FakeFireSettingsRepository(initialSettings: demo.fireSettings),
  ),
  flutterLocalNotificationsPluginProvider.overrideWithValue(
    FlutterLocalNotificationsPlugin(),
  ),
  firestoreProvider.overrideWithValue(_NoFirestore()),
  legacyCurrencyBackfillServiceProvider.overrideWithValue(null),
  usdTagRepairServiceProvider.overrideWithValue(null),
  connectivityStatusProvider.overrideWith((ref) => Stream.value(true)),
  inAppUpdateProvider.overrideWith(_NoUpdateNotifier.new),
  currencyConversionServiceProvider.overrideWithValue(_OfflineCurrency()),
];

/// Everything is INR here, so no conversion is ever needed; anything that
/// does reach Firestore fails loudly instead of showing a made-up value.
class _NoFirestore extends Fake implements FirebaseFirestore {}

class _OfflineCurrency extends MockCurrencyConversionService {
  @override
  Future<void> refreshLiveCacheIfStale() async {}

  @override
  Future<void> preloadRates(
    Set<String> currencies,
    String baseCurrency,
  ) async {}
}

class _NoUpdateNotifier extends InAppUpdateNotifier {
  @override
  InAppUpdateState build() => const InAppUpdateState();

  @override
  Future<void> checkForUpdate() async {}
}

/// Sizes the view like the Play screenshots and starts the real app on
/// [demo], signed in and with no lock, update prompt or banner.
Future<void> pumpStoreApp(WidgetTester tester, StoreDemoData demo) async {
  // Release builds have no debug banner, and flutter_test draws elevation
  // shadows as solid outlines where a device draws soft ones. The test
  // framework checks these flags before tearDown callbacks run, so the test
  // calls [releaseStoreApp] itself.
  WidgetsApp.debugAllowBannerOverride = false;
  debugDisableShadows = false;
  tester.view
    ..physicalSize = storeScreenshotSize
    ..devicePixelRatio = _pixelRatio
    ..padding = const FakeViewPadding(top: _statusBarPx)
    ..viewPadding = const FakeViewPadding(top: _statusBarPx);
  addTearDown(tester.view.reset);

  final app = await TestApp.create(tester);
  app.seedInvestments(demo.investments, demo.cashFlows);
  app.seedGoals(demo.goals);
  await app.pumpApp(extraOverrides: _storeOverrides(demo));
  await _settle(tester);
}

/// Puts back what [pumpStoreApp] changed. Call it in a `finally` at the end
/// of the test body.
void releaseStoreApp() {
  WidgetsApp.debugAllowBannerOverride = true;
  debugDisableShadows = true;
}

/// Fixed frames rather than pumpAndSettle, which never returns while the app
/// runs an endless animation.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Fails when the screen is not in the state a store image should show.
Future<void> expectSceneReady(WidgetTester tester, String scene) async {
  await _settle(tester);
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '$scene is still loading',
  );
  expect(find.text('Retry'), findsNothing, reason: '$scene shows an error');
  expect(
    find.byType(ErrorWidget),
    findsNothing,
    reason: '$scene has a build error',
  );
  expect(
    _familiesInTestFont(tester),
    isEmpty,
    reason: '$scene has text in a font that was not loaded',
  );
}

/// Font families on screen that render as test boxes.
Set<String> _familiesInTestFont(WidgetTester tester) {
  final found = <String>{};
  void checkSpan(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return;
    final style = inherited?.merge(span.style) ?? span.style;
    final family = style?.fontFamily;
    if (span.text != null &&
        style != null &&
        family != null &&
        family != 'MaterialIcons' &&
        family != _emojiFamily &&
        !_isSymbolOnly(span.text!)) {
      final key = '$family@${style.fontWeight?.value ?? 400}';
      if (_measured.putIfAbsent(key, () => _rendersAsTestFont(style))) {
        found.add(key);
      }
    }
    span.children?.forEach((child) => checkSpan(child, style));
  }

  void visit(RenderObject object) {
    if (object is RenderParagraph) checkSpan(object.text, null);
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return found;
}

/// Icon glyphs and emoji sit in private-use or symbol blocks: no letters.
bool _isSymbolOnly(String text) => !RegExp('[A-Za-z]').hasMatch(text);

final _amountPattern = RegExp(
  r'₹\s?\d|\d[\d,]*(\.\d+)?\s?(%|x\b|L\b|Cr\b|K\b)|\d{1,3}(,\d{2,3})+',
);

/// Every text and semantics label that shows an amount: a ₹ sign before a
/// number, a percentage, a multiple, lakh/crore/thousand notation, or digits
/// grouped by commas. Text that is hidden (blurred or transparent, as privacy
/// mode does) is skipped; screen readers skip it too.
List<String> amountsOnScreen(WidgetTester tester) {
  final strings = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph && !_isHidden(object)) {
      strings.add(object.text.toPlainText());
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);

  void visitSemantics(SemanticsNode node) {
    final data = node.getSemanticsData();
    strings
      ..add(data.label)
      ..add(data.value)
      ..add(data.hint)
      ..add(data.tooltip);
    node.visitChildren((child) {
      visitSemantics(child);
      return true;
    });
  }

  final root =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visitSemantics(root);

  return strings.where(_amountPattern.hasMatch).toList();
}

/// True when something above [object] stops it being seen: a blur, zero
/// opacity, or an offstage subtree.
bool _isHidden(RenderObject object) {
  for (RenderObject? up = object.parent; up != null; up = up.parent) {
    if (up is RenderOpacity && up.opacity == 0) return true;
    if (up is RenderAnimatedOpacity && up.opacity.value == 0) return true;
    if (up is RenderOffstage && up.offstage) return true;
    // ImageFiltered's render object is private; the only filter used is the
    // privacy blur.
    if (up.runtimeType.toString().contains('ImageFilter')) return true;
  }
  return false;
}

/// Renders the screen to 1080x1920, checks the picture, and writes it as
/// `<STORE_SCREENSHOTS_DIR>/<name>.png` when that variable is set.
Future<void> captureScene(WidgetTester tester, String name) async {
  _giveEmojiAFont(tester);
  await tester.pump();

  late ui.Image image;
  late Uint8List rgba;
  await tester.runAsync(() async {
    final renderView = tester.binding.renderViews.first;
    final layer = renderView.debugLayer! as OffsetLayer;
    image = await layer.toImage(renderView.paintBounds);
    rgba = (await image.toByteData())!.buffer.asUint8List();
  });
  expect(
    [image.width, image.height],
    [storeScreenshotSize.width.toInt(), storeScreenshotSize.height.toInt()],
    reason: '$name is not 1080x1920',
  );
  expect(_distinctColours(rgba), greaterThan(8), reason: '$name is blank');

  final dir = storeScreenshotsDir;
  if (dir == null) return;
  final png = encodeRgbPng(image.width, image.height, rgba);
  await tester.runAsync(() async {
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(png);
  });
  debugPrint(
    'store screenshots: wrote $dir/$name.png (${png.length ~/ 1024} KB)',
  );
}

int _distinctColours(Uint8List rgba) {
  final seen = <int>{};
  for (var i = 0; i < rgba.length && seen.length < 64; i += 4 * 997) {
    seen.add(rgba[i] << 16 | rgba[i + 1] << 8 | rgba[i + 2]);
  }
  return seen.length;
}

/// The test engine has no system emoji fallback, so a paragraph holding an
/// emoji gets the emoji font as fallback. Device text already falls back to
/// the system emoji font, which is this same one on Android.
void _giveEmojiAFont(WidgetTester tester) {
  void visit(RenderObject object) {
    if (object is RenderParagraph) {
      final text = object.text;
      if (text is TextSpan && _hasEmoji(text.toPlainText())) {
        object.text = TextSpan(
          text: text.text,
          children: text.children,
          style: (text.style ?? const TextStyle()).copyWith(
            fontFamilyFallback: const [_emojiFamily],
          ),
          semanticsLabel: text.semanticsLabel,
        );
      }
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
}

bool _hasEmoji(String text) => RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
).hasMatch(text);
