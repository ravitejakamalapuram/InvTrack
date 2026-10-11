// Shared by card_guard_360_test.dart and card_guard_411_test.dart.
//
// Pumps one real card at a time (the Overview hero, the goal cards, the
// Investment detail stats) at a phone width, a text scale, a reading direction
// and with privacy mode on or off, and measures render boxes (never pixels).
// The test font draws every glyph as a same-width square, so every run uses the
// real fonts and refuses to start without them.
//
// A failed check is collected, not thrown, so one run lists every card that is
// off. The message names the case and the measured value in dp.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/screen_layout.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../helpers/text_geometry.dart' show paragraphBaselineY, paragraphLines;
import '../mocks/mock_analytics_service.dart';
import '../store_screenshots/store_screenshot_harness.dart'
    show loadStoreScreenshotFonts;
import 'layout_guard_harness.dart' show guardTolerance;

const _pixelRatio = 2.625;

/// Phone height in dp; only the width and the text scale vary.
const _guardHeight = 900.0;

/// The character a hidden amount is drawn with, five times.
const hiddenAmountText = '•••••';

/// The key `StatColumns` puts on the cell of column [i]. Written out here so
/// the guard states what it expects of the widget.
ValueKey<String> statCellKey(int i) => ValueKey('stat-column-$i');

/// The key `StatColumns` puts on the value of column [i].
ValueKey<String> statValueKey(int i) => ValueKey('stat-value-$i');

class _FixedPrivacy extends PrivacyModeNotifier {
  _FixedPrivacy(this.value);
  final bool value;

  @override
  bool build() => value;
}

/// Runs [body] at [width] dp and [textScale], then fails with every violation
/// it collected, and with every overflow or error the cards reported.
Future<void> runCardGuard(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Future<void> Function(CardGuard guard) body,
}) async {
  final fonts = await loadStoreScreenshotFonts(tester);
  expect(
    fonts.testFontFamilies,
    isEmpty,
    reason: 'these families would render as solid test boxes',
  );

  final guard = CardGuard._(tester, width: width, textScale: textScale);
  final previousOnError = FlutterError.onError;
  FlutterError.onError = guard._record;
  final semantics = tester.ensureSemantics();
  tester.view
    ..physicalSize = Size(width * _pixelRatio, _guardHeight * _pixelRatio)
    ..devicePixelRatio = _pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  try {
    await body(guard);
    guard._verify();
  } finally {
    FlutterError.onError = previousOnError;
    semantics.dispose();
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  }
}

/// Collects measurements and violations for one run.
class CardGuard {
  CardGuard._(this.tester, {required this.width, required this.textScale});

  final WidgetTester tester;
  final double width;
  final double textScale;

  final _violations = <String>[];
  final _errors = <String>[];

  /// Names the case a violation belongs to; set by the caller.
  String scope = '';

  /// Whether the card under test is read right to left.
  bool rtl = false;

  void _record(FlutterErrorDetails details) {
    final text = details.toString();
    if (text.contains('overflowed by')) {
      final summary = text
          .split('\n')
          .where(
            (l) =>
                l.contains('overflowed by') ||
                l.contains('error-causing widget') ||
                RegExp(r'lib/\S+\.dart').hasMatch(l),
          )
          .take(4)
          .map((l) => l.trim())
          .join(' | ');
      _errors.add('[$scope] overflow: $summary');
    } else {
      _errors.add(
        '[$scope] error while laying out: '
        '${details.exceptionAsString().split('\n').first}',
      );
    }
  }

  void _verify() {
    final problems = [..._violations, ..._errors];
    if (problems.isNotEmpty) {
      fail(
        '${problems.length} layout problem(s) at ${width.toInt()}dp, text '
        'x$textScale:\n${problems.map((p) => '  - $p').join('\n')}',
      );
    }
  }

  void fault(String message) => _violations.add('[$scope] $message');

  /// [v] as dp with one decimal, for messages.
  String dp(double v) => v.toStringAsFixed(1);

  // -- Pumping -------------------------------------------------------------

  /// Builds [child] on a screen edge like the real screens do, in the base
  /// currency INR, and settles the privacy and opacity animations.
  Future<void> pump(
    Widget child, {
    List<Override> overrides = const [],
    bool privacy = false,
    bool rtl = false,
  }) async {
    this.rtl = rtl;
    await tester.pumpWidget(
      ProviderScope(
        // A fresh scope per call: provider families with another override
        // list cannot be swapped inside a scope that already exists.
        key: UniqueKey(),
        overrides: [
          privacyModeProvider.overrideWith(() => _FixedPrivacy(privacy)),
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          currencySymbolProvider.overrideWith((ref) => '₹'),
          currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // The app's theme: text without a font of its own takes its family
          // from it, as in the app; without it that text is drawn in squares.
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, app) => Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: app!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(child: ScreenEdge(child: child)),
          ),
        ),
      ),
    );
    // The privacy switcher takes 300ms, the badge fade 200ms.
    await tester.pump(const Duration(seconds: 1));
  }

  // -- Measuring -----------------------------------------------------------

  Finder _within(Finder of, Finder what) =>
      find.descendant(of: of, matching: what);

  /// The one render box of [finder], or null (and a fault) when it is not on
  /// screen. With several matches the first in the tree is used.
  RenderBox? box(String what, Finder finder) {
    if (finder.evaluate().isEmpty) {
      fault('$what: not on screen');
      return null;
    }
    return tester.renderObject<RenderBox>(finder.first);
  }

  Rect? rect(String what, Finder finder) {
    final b = box(what, finder);
    if (b == null) return null;
    return b.localToGlobal(Offset.zero) & b.size;
  }

  /// The paragraph that draws [finder]: the finder itself when it is a text,
  /// else the first text below it.
  RenderParagraph? paragraph(String what, Finder finder) {
    if (finder.evaluate().isEmpty) {
      fault('$what: not on screen');
      return null;
    }
    final inner = _within(finder.first, find.byType(RichText));
    final target = inner.evaluate().isEmpty ? finder.first : inner.first;
    final object = tester.renderObject(target);
    if (object is! RenderParagraph) {
      fault('$what: is not a text');
      return null;
    }
    return object;
  }

  /// y (dp, screen) of the baseline of the first or last line of [finder].
  double? baselineY(String what, Finder finder, {bool last = false}) {
    final p = paragraph(what, finder);
    return p == null ? null : paragraphBaselineY(p, last: last);
  }

  /// The box that all the glyphs of [finder] fill (screen coordinates). The
  /// spaces are left out: a space that ends a wrapped line hangs past it.
  Rect? textRect(String what, Finder finder) {
    final p = paragraph(what, finder);
    if (p == null) return null;
    Rect? rect;
    for (final word in RegExp(r'\S+').allMatches(p.text.toPlainText())) {
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      );
      for (final box in boxes) {
        rect = rect == null ? box.toRect() : rect.expandToInclude(box.toRect());
      }
    }
    final origin = p.localToGlobal(Offset.zero);
    return rect == null ? origin & p.size : rect.shift(origin);
  }

  /// Where the text of [finder] starts and ends along the line, in the
  /// reading direction of the run: x of its first glyph's edge and of its
  /// last glyph's edge.
  ({double start, double end})? textExtent(String what, Finder finder) {
    final r = textRect(what, finder);
    if (r == null) return null;
    return rtl ? (start: r.right, end: r.left) : (start: r.left, end: r.right);
  }

  int? lineCount(String what, Finder finder) {
    final p = paragraph(what, finder);
    return p == null ? null : paragraphLines(p).length;
  }

  /// x of the edge of [r] where a line starts / ends in the run's direction.
  double startOf(Rect r) => rtl ? r.right : r.left;
  double endOf(Rect r) => rtl ? r.left : r.right;

  /// Where the [icon] below [within] starts along the line.
  double? iconStart(String what, Finder within, IconData icon) {
    final r = rect(
      what,
      find.descendant(of: within, matching: find.byIcon(icon)),
    );
    return r == null ? null : startOf(r);
  }

  // -- Checks --------------------------------------------------------------

  void expectNear(String what, double? actual, double want) {
    if (actual == null) return;
    if ((actual - want).abs() > guardTolerance) {
      fault('$what is ${dp(actual)}dp, want ${dp(want)}dp');
    }
  }

  void expectAtMost(String what, double? actual, double limit) {
    if (actual == null) return;
    if (actual > limit + guardTolerance) {
      fault('$what is ${dp(actual)}dp, want at most ${dp(limit)}dp');
    }
  }

  /// The text of [finder] is whole: no clipped line, and no word wider than
  /// the line (which Flutter would break in the middle). With
  /// [noEllipsisNet] the text must also not be able to end in an ellipsis at
  /// all, which is what a chip or a footer promises; amounts keep one as a
  /// last resort and only promise that it does not fire.
  void expectWholeWords(
    String what,
    Finder finder, {
    bool noEllipsisNet = false,
  }) {
    final p = paragraph(what, finder);
    if (p == null) return;
    if (p.didExceedMaxLines) fault('$what: is cut off by maxLines');
    if (noEllipsisNet && p.maxLines != null) {
      fault('$what: can be cut off, it has maxLines ${p.maxLines}');
    }
    if (noEllipsisNet && p.overflow == TextOverflow.ellipsis) {
      fault('$what: can end in an ellipsis');
    }
    final span = p.text;
    final style = span is TextSpan ? span.style : null;
    for (final word in span.toPlainText().split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        locale: p.locale,
      )..layout();
      final w = painter.width;
      painter.dispose();
      if (w > p.size.width + 0.01) {
        fault(
          '$what: the word "$word" is ${dp(w)}dp wide in a ${dp(p.size.width)}'
          'dp line, so it is broken in the middle',
        );
      }
    }
  }
}
