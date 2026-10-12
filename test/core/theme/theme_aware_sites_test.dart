// Source scan: a colour made for the light theme must not be painted
// unconditionally, nor in the dark theme.
//
// The constants below are the light-theme text colours (and the one dark
// grey) that the contrast PRs change. A site that reads one of them without a
// theme check paints it in both themes, so changing its value would also change
// the dark theme, where the old value was the readable one. A site passes when
//
//  1. it sits in a branch of a ternary whose condition tests the theme, and the
//     colour is in the branch of its own theme: a `...Light` colour in the
//     light branch, `neutral500Dark` in the dark one. A condition tests the
//     theme when it is `isDark`, `!isDark`, `isDark == false` or a comparison
//     of `brightness` with `Brightness.dark` or `Brightness.light`, alone or
//     inside a larger condition (`isDark && ok`). The ternary may be several
//     brackets out, and it need not be the nearest one: in
//     `isDark ? a : ok ? x : y` the theme governs `x`. A theme word anywhere
//     else near the site does not count, and neither does a longer name that
//     contains one (`screenBrightness`, `isDarkChartEnabled`); or
//  2. it is a tint: `.withValues(alpha: 0.5)` or less applied to it; or
//  3. the line carries a `theme-neutral:` comment, or the comment line just
//     above it does, saying why the same colour belongs in both themes (a
//     fill under a white label). Each file's count of these is a literal in
//     [_neutral], so adding one shows in the test diff.
//
// A colour in the wrong branch (`isDark ? errorLight : errorDark`) fails with
// no allowlist, tint apart. The direction is read only when the condition is
// one theme test: `isDark && ok ? a : b` passes either way.
//
// The check reads text, not types. It cannot tell a label from a fill, so rule
// 2 passes a translucent text colour and rule 3 is the author's word. A colour
// inside a string interpolation is not seen (none exists in lib/). A reviewer
// reads the `theme-neutral:` comments.
//
// The tint rule ([tintedStatusSites]) reads text too. It sees a tint written on
// the deeper green or red, or on `colorScheme.error`, directly or on a group. It
// does not see a tint of a colour held in a variable (`color.withValues(...)`
// where `color` was picked from `successLight` a few lines up): those sites
// carry a separate tint by hand (`_MaturityInfo.tint`, `_tint`, `tint:`), and
// widget tests that pump them read the real text and the real tint.
//
// The blue and amber text colours (`accentTextLight`, `warningTextLight`) are
// scanned like the others. `accentLight` and `warningLight` keep their bright
// value for fills, tints, borders and gradients, and they are still scanned for
// a theme check; [brightSites] counts the reads that are not a tint, so a text
// or an icon that goes back to the bright colour changes a count in [_bright].
// A site that reads `accentLight` for a text is a contrast bug in light.
//
// A new constant in app_colors.dart that is an alias of a listed one is found
// by [unlistedAliases]. One with a value of its own is not: the PR that adds it
// adds it to [_constants].
//
// Files still to fix are counted in [_unfixed]. The count must match exactly:
// a new site in a listed file fails, and so does a fixed one that is still
// counted. Later PRs in the stack lower the counts and delete the entries.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _constants = [
  'neutral500Light',
  'textSecondaryLight',
  'neutral400Light',
  'neutral500Dark',
  'successLight',
  'dangerLight',
  'errorLight',
  'accentLight',
  'warningLight',
  // The deeper blue and amber for text and icons. Light only: in dark the text
  // is `accentDark` and `warningDark`.
  'accentTextLight',
  'warningTextLight',
  // The old, brighter green and red. They are kept as tint sources, so they
  // may be painted translucent, or in a branch of a theme check; never bare.
  'successTintLight',
  'dangerTintLight',
];

/// The status colours that got deeper so that text in them reads on white. A
/// tint made of one would follow the new value, and text on that tint falls
/// back under 4.5:1 (4.34 for green, 4.38 for red at 15%); tints are made of
/// `successTintLight` and `dangerTintLight`, which keep the old hue.
/// `colorScheme.error` is `dangerLight` in the light theme, so it counts too.
/// The blue and amber text colours are in the list for the same reason: a tint
/// of one is 4.45 and 4.25 under its own label at 15%, and the chip is tinted with
/// `accentLight` or `warningLight` instead.
const _deepStatusConstants = [
  'successLight',
  'errorLight',
  'dangerLight',
  'accentTextLight',
  'warningTextLight',
];

/// The bright blue and amber, for fills, tints, borders and gradients. A read
/// of one that is not a tint is a fill, a tint source held in a variable, or a
/// text that still needs fixing.
const _brightConstants = ['accentLight', 'warningLight'];

/// How many reads of [_brightConstants] that are not a tint each file keeps
/// (see [brightSites]). Each is a fill, a tint source or a ring, never a text
/// or an icon. Raising a number, or adding a file, needs a reason in the PR
/// body.
const _bright = <String, int>{
  // The step number's circle: a white digit on a fill, twice (unjudged by the
  // audit: white on the bright blue is 2.77).
  'lib/features/bulk_import/presentation/screens/bulk_import_screen.dart': 2,
  // colorForBrightness is the fill and tint hue; textColor is the text.
  'lib/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart':
      2,
  // The milestone's progress ring.
  'lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart': 1,
  // The tint behind the setup card's icon.
  'lib/features/fire_number/presentation/widgets/fire_dashboard_card.dart': 1,
  // The tints behind the FIRE and Barista icons.
  'lib/features/fire_number/presentation/widgets/fire_stats_card.dart': 2,
  // Hidden until the Income Guardian flag is on (A42): the status colour is
  // text and tint at once there. Split before the flag is turned on.
  'lib/features/income_projection/presentation/screens/income_guardian_settings_screen.dart':
      1,
  'lib/features/income_projection/presentation/widgets/expected_income_section.dart':
      2,
  'lib/features/income_projection/presentation/widgets/income_cell.dart': 2,
  // The tints of the maturity chip and the maturity row.
  'lib/features/investment/presentation/widgets/investment_card.dart': 3,
  'lib/features/investment/presentation/widgets/investment_detail_stats_section.dart':
      3,
  // A gradient behind a white icon.
  'lib/features/onboarding/presentation/screens/onboarding_screen.dart': 1,
  // The tile's tint source (its icon takes the text colour).
  'lib/features/overview/presentation/widgets/overview_empty_state.dart': 1,
  // The suggestion number's circle: a white digit on a fill.
  'lib/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart':
      1,
  // The tint behind the insight icon.
  'lib/features/reports/presentation/widgets/smart_insight_card.dart': 1,
  // The tint of the danger-zone tile and the Replace option, the amber
  // snackbar fill and the amber button fill.
  'lib/features/settings/presentation/screens/data_management_screen.dart': 4,
};

/// Sites not yet fixed, by file: how many are left. Raising a number, or adding
/// a file, needs a reason in the PR body. None are left.
const _unfixed = <String, int>{};

/// Sites kept on a `theme-neutral:` comment, by file: how many. A comment in
/// `lib/` is outside the diff a reviewer reads, so each one needs a number here
/// and a reason in the PR body.
const _neutral = <String, int>{
  // The selected fill of the frequency chip, under a white label in both themes.
  'lib/features/investment/presentation/screens/add_investment_screen.dart': 1,
  // The page gradients behind a white icon, the same in both themes.
  'lib/features/onboarding/presentation/screens/onboarding_screen.dart': 2,
  // The Success and Error swatches of the theme preview, under white labels.
  'lib/features/settings/presentation/screens/appearance_settings_screen.dart':
      2,
  // The import-warnings snackbar: amber fill under fixed dark ink text.
  'lib/features/settings/presentation/screens/data_management_screen.dart': 1,
};

/// Never scanned: they define the constants and build both themes explicitly.
const _skipped = [
  'lib/core/theme/app_colors.dart',
  'lib/core/theme/app_theme.dart',
];

typedef Site = ({int line, String constant, String expression});

/// [source] with comments and string contents turned into spaces, so the
/// brackets and commas in them are not read. Offsets and lines are unchanged.
String blankCommentsAndStrings(String source) {
  final out = StringBuffer();
  String blank(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      var end = source.indexOf('\n', i);
      if (end < 0) end = source.length;
      out.write(blank(source.substring(i, end)));
      i = end;
    } else if (source.startsWith('/*', i)) {
      final close = source.indexOf('*/', i + 2);
      final end = close < 0 ? source.length : close + 2;
      out.write(blank(source.substring(i, end)));
      i = end;
    } else if (source[i] == "'" || source[i] == '"') {
      final quote = source[i];
      final isRaw = i > 0 && source[i - 1] == 'r';
      final open = source.startsWith(quote * 3, i) ? quote * 3 : quote;
      var j = i + open.length;
      while (j < source.length && !source.startsWith(open, j)) {
        j += !isRaw && source[j] == r'\' ? 2 : 1;
      }
      // An unterminated string runs to the end of the file.
      final end = j < source.length ? j : source.length;
      out
        ..write(open)
        ..write(blank(source.substring(i + open.length, end)))
        ..write(j < source.length ? open : '');
      i = j < source.length ? j + open.length : source.length;
    } else {
      out.write(source[i++]);
    }
  }
  return out.toString();
}

/// The expression around [start]..[end]: back to the nearest `,` `;` `=` `=>`
/// or unmatched opening bracket, forward to the nearest `,` `;` or unmatched
/// closing bracket. Brackets inside it are skipped over.
(int, int) expressionAround(String code, int start, int end) {
  var depth = 0;
  var from = start - 1;
  for (; from >= 0; from--) {
    final c = code[from];
    if (')]}'.contains(c)) {
      depth++;
    } else if ('([{'.contains(c)) {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0) {
      final prev = from > 0 ? code[from - 1] : '';
      final next = from + 1 < code.length ? code[from + 1] : '';
      if (',;'.contains(c)) break;
      if (c == '>' && prev == '=') break; // =>
      if (c == '=' && !'=>'.contains(next) && !'=!<>'.contains(prev)) break;
    }
  }
  depth = 0;
  var to = end;
  for (; to < code.length; to++) {
    final c = code[to];
    if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0 && ',;'.contains(c)) {
      break;
    }
  }
  return (from + 1, to);
}

final _tint = RegExp(r'\s*\.withValues\(\s*alpha:\s*([0-9.]+)\s*,?\s*\)');
// Comments are blanked before the scan, so whitespace is all that can sit
// between the class and the name.
final _occurrence = RegExp(
  '\\bAppColors\\s*\\.\\s*(${_constants.join('|')})\\b',
);

final _statusOccurrence = RegExp(
  '\\bAppColors\\s*\\.\\s*(${_deepStatusConstants.join('|')})\\b'
  r'|\bcolorScheme\s*\.\s*(error)\b',
);
final _tintCall = RegExp(r'\s*\.\s*(?:withValues|withOpacity|withAlpha)\s*\(');

bool _isTint(String code, int at) {
  final m = _tint.matchAsPrefix(code, at);
  return m != null && double.parse(m.group(1)!) <= 0.5;
}

/// What is open at one bracket level while [_themeBranch] reads along: where
/// the current operand began, and the condition text of each ternary whose
/// branch we are in.
class _Level {
  _Level(this.operand);
  int operand;
  final conditions = <String>[];
  final inThen = <bool>[];

  void reset(int at) {
    operand = at;
    conditions.clear();
    inThen.clear();
  }
}

/// The theme a ternary condition is true in: [mixed] for a condition that tests
/// the theme and something else, [none] for one that does not test it.
enum _Theme { none, mixed, dark, light }

/// Where a site sits: in no theme branch, in one whose direction is not known,
/// or in the light or dark branch of a theme ternary. A larger value wins when
/// several ternaries govern the site.
enum _Branch { none, themed, light, dark }

final _isDarkWord = RegExp(r'(?<![\w$])isDark(?![\w$])');
final _brightnessCompare = RegExp(
  r'(?<![\w$])brightness\s*[!=]=\s*Brightness\.(?:dark|light)\b',
);
final _pureIsDark = RegExp(r'^(?:\w+\.)*isDark(?:==(true|false))?$');
final _pureBrightness = RegExp(
  r'^(?:[\w.()]*\.)?brightness(==|!=)Brightness\.(dark|light)$',
);

/// Whether [word] stands at [at] in [code] as a whole word.
bool _isKeyword(String code, int at, String word) {
  bool wordChar(String ch) => RegExp(r'[\w$]').hasMatch(ch);
  final end = at + word.length;
  return code.startsWith(word, at) &&
      (at == 0 || !wordChar(code[at - 1])) &&
      (end >= code.length || !wordChar(code[end]));
}

/// [s] without the brackets that wrap all of it.
String _unwrap(String s) {
  while (s.length > 1 && s.startsWith('(') && s.endsWith(')')) {
    var depth = 0;
    var wraps = true;
    for (var i = 0; i < s.length - 1 && wraps; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') wraps = --depth > 0;
    }
    if (!wraps) break;
    s = s.substring(1, s.length - 1);
  }
  return s;
}

_Theme _themeOf(String condition) {
  var c = condition.replaceAll(RegExp(r'\s+'), '');
  var negated = false;
  c = _unwrap(c);
  while (c.startsWith('!')) {
    negated = !negated;
    c = _unwrap(c.substring(1));
  }
  _Theme? pure;
  final isDark = _pureIsDark.firstMatch(c);
  final brightness = _pureBrightness.firstMatch(c);
  if (isDark != null) {
    pure = isDark.group(1) == 'false' ? _Theme.light : _Theme.dark;
  } else if (brightness != null) {
    final dark =
        (brightness.group(1) == '==') == (brightness.group(2) == 'dark');
    pure = dark ? _Theme.dark : _Theme.light;
  }
  if (pure == null) {
    return _isDarkWord.hasMatch(condition) ||
            _brightnessCompare.hasMatch(condition)
        ? _Theme.mixed
        : _Theme.none;
  }
  if (!negated) return pure;
  return pure == _Theme.dark ? _Theme.light : _Theme.dark;
}

/// Where the text at [pos] in [code] (comments and strings blanked) sits among
/// the ternaries whose condition tests the theme. Reads from the start of the
/// file with one [_Level] per open bracket, so a ternary in a sibling argument
/// is gone by the time its bracket closes, and one around the site still
/// counts from inside nested calls. A `,` or `;` ends the ternaries of its
/// level.
_Branch _themeBranch(String code, int pos) {
  final levels = [_Level(0)];
  for (var i = 0; i < pos; i++) {
    final c = code[i];
    final level = levels.last;
    final prev = i > 0 ? code[i - 1] : ' ';
    final next = i + 1 < code.length ? code[i + 1] : ' ';
    if ('([{'.contains(c)) {
      levels.add(_Level(i + 1));
    } else if (')]}'.contains(c)) {
      if (levels.length > 1) levels.removeLast();
    } else if (',;'.contains(c)) {
      level.reset(i + 1);
    } else if (c == 'r' && _isKeyword(code, i, 'return')) {
      level.reset(i + 'return'.length); // a statement of its own
    } else if (c == '?' && ' \n'.contains(prev) && !'?.['.contains(next)) {
      level.conditions.add(code.substring(level.operand, i));
      level.inThen.add(true);
      level.operand = i + 1;
    } else if (c == ':') {
      // Closes the innermost ternary still in its first branch; with none
      // open, it ends a name (`color:`).
      final open = level.inThen.lastIndexOf(true);
      if (open >= 0) level.inThen[open] = false;
      level.operand = i + 1;
    } else if (c == '>' && prev == '=') {
      level.operand = i + 1; // =>
    } else if (c == '=' && !'=>'.contains(next) && !'=!<>'.contains(prev)) {
      level.operand = i + 1;
    }
  }
  var branch = _Branch.none;
  for (final level in levels) {
    for (var k = 0; k < level.conditions.length; k++) {
      final inThen = level.inThen[k];
      final here = switch (_themeOf(level.conditions[k])) {
        _Theme.none => _Branch.none,
        _Theme.mixed => _Branch.themed,
        _Theme.dark => inThen ? _Branch.dark : _Branch.light,
        _Theme.light => inThen ? _Branch.light : _Branch.dark,
      };
      if (here.index > branch.index) branch = here;
    }
  }
  return branch;
}

typedef Scan = ({
  List<Site> unguarded,
  List<Site> neutral,
  List<Site> reversed,
});

/// The sites in [source] that read one of the listed constants. A site in the
/// wrong branch of a theme ternary is reversed. One in no theme branch and not
/// a tint is unguarded, or neutral when it has a `theme-neutral:` comment.
Scan scan(String source) {
  final code = blankCommentsAndStrings(source);
  final lines = source.split('\n');
  final unguarded = <Site>[];
  final neutral = <Site>[];
  final reversed = <Site>[];
  for (final m in _occurrence.allMatches(code)) {
    final constant = m.group(1)!;
    final branch = _themeBranch(code, m.start);
    final wrongWay = constant.endsWith('Light')
        ? branch == _Branch.dark
        : branch == _Branch.light;
    if (branch != _Branch.none && !wrongWay) continue;
    final (from, to) = expressionAround(code, m.start, m.end);
    // `(a ? x : y).withValues(...)` tints the whole group.
    final closes = to < code.length && code[to] == ')';
    if (_isTint(code, m.end) || (closes && _isTint(code, to + 1))) continue;
    final line = '\n'.allMatches(code.substring(0, m.start)).length;
    final site = (
      line: line + 1,
      constant: constant,
      expression: code
          .substring(from, to)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' '),
    );
    final marked =
        lines[line].contains('theme-neutral:') ||
        (line > 0 &&
            lines[line - 1].trimLeft().startsWith('//') &&
            lines[line - 1].contains('theme-neutral:'));
    (wrongWay
            ? reversed
            : marked
            ? neutral
            : unguarded)
        .add(site);
  }
  return (unguarded: unguarded, neutral: neutral, reversed: reversed);
}

/// The sites that read a listed constant with no theme branch, no tint
/// and no `theme-neutral:` comment.
List<Site> unguardedSites(String source) => scan(source).unguarded;

/// The sites that pass only because of a `theme-neutral:` comment.
List<Site> neutralSites(String source) => scan(source).neutral;

/// The sites that read a light colour in the dark branch of a theme ternary, or
/// the dark grey in the light branch.
List<Site> reversedSites(String source) => scan(source).reversed;

/// The sites in [source] where a tint is made of a status colour that got
/// deeper: `.withValues(...)`, `.withOpacity(...)` or `.withAlpha(...)` on
/// `successLight`, `errorLight` or `dangerLight`, directly or on a group that
/// holds one (`(isDark ? a : AppColors.errorLight).withValues(...)`).
List<Site> tintedStatusSites(String source) {
  final code = blankCommentsAndStrings(source);
  final sites = <Site>[];
  for (final m in _statusOccurrence.allMatches(code)) {
    final (from, to) = expressionAround(code, m.start, m.end);
    // `(a ? x : y).withValues(...)` tints the whole group.
    final closes = to < code.length && code[to] == ')';
    if (_tintCall.matchAsPrefix(code, m.end) == null &&
        !(closes && _tintCall.matchAsPrefix(code, to + 1) != null)) {
      continue;
    }
    sites.add((
      line: '\n'.allMatches(code.substring(0, m.start)).length + 1,
      constant: m.group(1) ?? 'colorScheme.${m.group(2)}',
      expression: code
          .substring(from, to)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' '),
    ));
  }
  return sites;
}

final _brightOccurrence = RegExp(
  '\\bAppColors\\s*\\.\\s*(${_brightConstants.join('|')})\\b',
);

/// The sites in [source] that read the bright blue or amber and are not a tint
/// of half strength or less, whatever the theme branch. What is left is a fill,
/// a tint source held in a variable, a ring, or a text that is not fixed.
List<Site> brightSites(String source) {
  final code = blankCommentsAndStrings(source);
  final sites = <Site>[];
  for (final m in _brightOccurrence.allMatches(code)) {
    final (from, to) = expressionAround(code, m.start, m.end);
    // `(a ? x : y).withValues(...)` tints the whole group.
    final closes = to < code.length && code[to] == ')';
    if (_isTint(code, m.end) || (closes && _isTint(code, to + 1))) continue;
    sites.add((
      line: '\n'.allMatches(code.substring(0, m.start)).length + 1,
      constant: m.group(1)!,
      expression: code
          .substring(from, to)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' '),
    ));
  }
  return sites;
}

/// The constants in [source] (app_colors.dart) that are plain aliases of one of
/// [listed], or of an alias, and are not in [listed].
List<String> unlistedAliases(String source, Iterable<String> listed) {
  final alias = RegExp(r'static const Color (\w+) = (\w+);');
  final known = {...listed};
  final found = <String>[];
  var grew = true;
  while (grew) {
    grew = false;
    for (final m in alias.allMatches(source)) {
      if (known.contains(m.group(2)) && known.add(m.group(1)!)) {
        found.add(m.group(1)!);
        grew = true;
      }
    }
  }
  return found;
}

void main() {
  group('the scan', () {
    List<int> found(String source) => [
      for (final s in unguardedSites(source)) s.line,
    ];

    test('passes a site whose expression mentions the theme', () {
      expect(
        found('''
final a = isDark ? AppColors.successDark : AppColors.successLight;
final b = Theme.of(context).brightness == Brightness.dark
    ? AppColors.errorDark
    : AppColors.errorLight;
Text('x', style: TextStyle(color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light));
'''),
        isEmpty,
      );
    });

    test('flags a bare site and a ternary with no theme in it', () {
      expect(
        found('''
final a = AppColors.successLight;
final b = up ? AppColors.successLight : AppColors.errorLight;
'''),
        [1, 2, 2],
      );
    });

    test('does not borrow the theme from a sibling argument', () {
      expect(
        found('''
Row(children: [
  Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
  Icon(Icons.add, color: AppColors.accentLight),
]);
'''),
        [3],
      );
    });

    test('passes a tint of half strength or less, flags a stronger one', () {
      expect(
        found('''
final a = AppColors.errorLight.withValues(alpha: 0.1);
final b = AppColors.errorLight.withValues(alpha: 0.5);
final c = (up ? AppColors.successLight : AppColors.errorLight).withValues(alpha: 0.15);
final d = AppColors.errorLight.withValues(alpha: 0.7);
'''),
        [4],
      );
    });

    test('reads a tint that the formatter split over lines', () {
      // dart format puts a long argument on its own line and adds a comma.
      expect(
        found('''
final a = AppColors.successLight.withValues(
  alpha: 0.15,
);
final b = AppColors.successLight.withValues(
  alpha: 0.7,
);
'''),
        [4],
      );
    });

    test('passes a site that says why it is the same in both themes', () {
      expect(
        found('''
// theme-neutral: a fill under a white label.
final a = AppColors.successLight;
final b = AppColors.successLight; // theme-neutral: a fill.
final c = AppColors.successLight;
'''),
        [4],
      );
    });

    test('lists the sites that pass only on that comment', () {
      const source = '''
// theme-neutral: a fill under a white label.
final a = AppColors.successLight;
final b = AppColors.successLight; // theme-neutral: a fill.
final c = AppColors.successLight;
final d = isDark ? AppColors.successDark : AppColors.successLight; // theme-neutral: not needed.
// theme-neutral: no constant below.
final e = 1;
''';
      expect([for (final s in neutralSites(source)) s.line], [2, 3]);
      expect([for (final s in unguardedSites(source)) s.line], [4]);
    });

    test('ignores comments and strings, and other constants', () {
      expect(
        found('''
// AppColors.successLight in a comment
/* AppColors.errorLight, isDark */
final a = 'AppColors.successLight';
final b = AppColors.successDark;
final c = AppColors.successLightBg;
'''),
        isEmpty,
      );
    });

    test(
      'flags a light colour in the branch of a ternary that is not the theme',
      () {
        expect(
          found('''
final a = ok ? AppColors.successLight : (isDark ? AppColors.successDark : AppColors.errorDark);
final b = ok ? (isDark ? AppColors.errorDark : AppColors.errorLight) : AppColors.errorDark;
final c = ok ? AppColors.accentLight : isDark ? AppColors.accentDark : AppColors.accentDark;
'''),
          [1, 3],
        );
      },
    );

    test('flags a light colour that only sits near a theme check', () {
      expect(
        found('''
final a = AppColors.successLight.withValues(alpha: isDark ? 0.9 : 0.8);
final b = _pick(isDark, AppColors.errorLight);
final c = (isDark ? 1 : 2) + (AppColors.accentLight == x ? 1 : 2);
'''),
        [1, 2, 3],
      );
    });

    test('passes a light colour in any branch of a theme ternary', () {
      expect(
        found('''
final a = isDark ? AppColors.successDark : ok ? AppColors.successLight : AppColors.errorDark;
final b = isDark ? x : Foo(AppColors.errorLight);
final c = ok ? (isDark ? AppColors.errorDark : AppColors.errorLight) : y;
final d = Theme.of(context).brightness == Brightness.dark ? 1 : AppColors.accentLight;
Text('x', style: TextStyle(color: isDark ? y : AppColors.warningLight, fontSize: 1));
'''),
        isEmpty,
      );
    });

    group('direction', () {
      List<int> reversed(String source) => [
        for (final s in reversedSites(source)) s.line,
      ];

      test('flags a light colour in the dark branch, whatever the form', () {
        const source = '''
final a = isDark ? AppColors.errorLight : AppColors.errorDark;
final b = !isDark ? AppColors.successDark : AppColors.successLight;
final c = Theme.of(context).brightness == Brightness.light ? AppColors.accentDark : AppColors.accentLight;
final d = brightness != Brightness.dark ? AppColors.warningDark : AppColors.warningLight;
final e = widget.isDark ? AppColors.errorLight : null;
final f = isDark == false ? AppColors.errorDark : AppColors.errorLight;
final g = !(Theme.of(context).brightness == Brightness.dark) ? AppColors.errorDark : AppColors.errorLight;
''';
        expect(reversed(source), [1, 2, 3, 4, 5, 6, 7]);
        expect(found(source), isEmpty);
      });

      test('flags the dark grey in the light branch', () {
        expect(
          reversed('''
final a = isDark ? AppColors.neutral400Light : AppColors.neutral500Dark;
final b = !isDark ? AppColors.neutral500Dark : AppColors.neutral400Light;
'''),
          [1, 1, 2, 2],
        );
      });

      test('passes each colour in the branch of its own theme', () {
        const source = '''
final a = isDark ? AppColors.neutral500Dark : AppColors.neutral400Light;
final b = !isDark ? AppColors.successLight : AppColors.successDark;
final c = Theme.of(context).brightness == Brightness.light ? AppColors.accentLight : AppColors.accentDark;
final d = isDark == false ? AppColors.warningLight : AppColors.warningDark;
final e = brightness != Brightness.light ? 1 : AppColors.errorLight;
final f = !(Theme.of(context).brightness == Brightness.dark) ? AppColors.errorLight : 1;
final g = isDark ? 1 : ok ? AppColors.errorLight : AppColors.successLight;
Widget h() {
  return isDark ? 1 : AppColors.errorLight;
}
''';
        expect(reversed(source), isEmpty);
        expect(found(source), isEmpty);
      });

      test('does not judge a tint, or a condition that tests more', () {
        const source = '''
final a = isDark ? AppColors.accentLight.withValues(alpha: 0.15) : AppColors.accentLight.withValues(alpha: 0.1);
final b = isDark && ok ? AppColors.successLight : AppColors.errorLight;
final c = ok || isDark ? AppColors.successLight : AppColors.errorLight;
''';
        expect(reversed(source), isEmpty);
        expect(found(source), isEmpty);
      });
    });

    test('a name that only contains a theme word is not a theme check', () {
      expect(
        found('''
final a = screenBrightness > 3 ? AppColors.successLight : AppColors.errorLight;
final b = isDarkChartEnabled ? AppColors.successLight : AppColors.errorLight;
final c = brightness > 3 ? AppColors.accentLight : AppColors.warningLight;
final d = x.isDarkish ? AppColors.accentLight : AppColors.warningLight;
'''),
        [1, 1, 2, 2, 3, 3, 4, 4],
      );
    });

    test('reads a name split from its class by a line break or a comment', () {
      // The formatter joins these, but an unformatted file must not slip past.
      const source = '''
final a = AppColors
    .neutral500Light;
final b = AppColors /* why */ . successLight;
final c = AppColors // why
    .errorLight;
final d = AppColors . accentLight;
final e = isDark ? AppColors
    .neutral400Light : AppColors.neutral500Dark;
final f = isDark ? AppColors
    .neutral500Dark : AppColors
    .neutral400Light;
''';
      expect(found(source), [1, 3, 4, 6]);
      expect([for (final s in reversedSites(source)) s.line], [7, 8]);
    });

    test('a bracket or comma inside a string does not end the expression', () {
      expect(
        found('''
final a = isDark ? 'a, (b' : AppColors.successLight;
'''),
        isEmpty,
      );
    });
  });

  group('the tint rule', () {
    List<int> tinted(String source) => [
      for (final s in tintedStatusSites(source)) s.line,
    ];

    test('flags a tint made of a deeper status colour, whatever the call', () {
      expect(
        tinted('''
final a = AppColors.successLight.withValues(alpha: 0.15);
final b = AppColors.errorLight.withOpacity(0.1);
final c = AppColors.dangerLight.withAlpha(30);
final d = AppColors.successLight.withValues(alpha: 0.9);
'''),
        [1, 2, 3, 4],
      );
    });

    test('flags a tint on a group that holds the colour', () {
      expect(
        tinted('''
final a = (isDark ? AppColors.errorDark : AppColors.errorLight).withValues(alpha: 0.7);
final b = (isDark
        ? AppColors.successDark
        : AppColors.successLight)
    .withValues(alpha: 0.7);
'''),
        [1, 4],
      );
    });

    test('reads a tint that the formatter moved to the next line', () {
      expect(
        tinted('''
final a = AppColors.successLight
    .withValues(
      alpha: 0.1,
    );
final b = AppColors
    .errorLight
    .withValues(alpha: 0.1);
'''),
        [1, 5],
      );
    });

    test('passes the tint sources and the dark colours', () {
      expect(
        tinted('''
final a = AppColors.successTintLight.withValues(alpha: 0.15);
final b = AppColors.dangerTintLight.withValues(alpha: 0.1);
final c = AppColors.successDark.withValues(alpha: 0.7);
final d = (isDark ? AppColors.errorDark : AppColors.dangerTintLight).withValues(alpha: 0.1);
final e = AppColors.accentLight.withValues(alpha: 0.1);
'''),
        isEmpty,
      );
    });

    test('passes the colour itself, and a tint in a sibling argument', () {
      expect(
        tinted('''
final a = AppColors.errorLight;
final b = Icon(Icons.add, color: AppColors.errorLight);
final c = Foo(AppColors.errorLight, other.withValues(alpha: 0.1));
final d = [AppColors.successLight, base.withValues(alpha: 0.1)];
'''),
        isEmpty,
      );
    });

    test('flags a tint of the theme error colour, the light red', () {
      expect(
        tinted('''
final a = Theme.of(context).colorScheme.error.withValues(alpha: 0.1);
final b = scheme.colorScheme
    .error
    .withOpacity(0.2);
final c = Theme.of(context).colorScheme.error;
final d = Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1);
final e = Theme.of(context).colorScheme.onError.withValues(alpha: 0.1);
'''),
        [1, 2],
      );
    });

    test('ignores comments and strings', () {
      expect(
        tinted('''
// color: AppColors.errorLight.withOpacity(0.1),
/* AppColors.successLight.withValues(alpha: 0.1) */
final a = 'AppColors.successLight.withValues(alpha: 0.1)';
'''),
        isEmpty,
      );
    });
  });

  group('the blue and amber text colours', () {
    List<int> found(String source) => [
      for (final s in unguardedSites(source)) s.line,
    ];

    test('are light colours: bare, they are flagged', () {
      expect(
        found('''
final a = AppColors.accentTextLight;
final b = Icon(Icons.add, color: AppColors.warningTextLight);
final c = isDark ? AppColors.accentDark : AppColors.accentTextLight;
final d = isDark ? AppColors.warningDark : AppColors.warningTextLight;
'''),
        [1, 2],
      );
    });

    test('in the dark branch they are reversed', () {
      expect(
        [
          for (final s in reversedSites(
            'final a = isDark ? AppColors.accentTextLight : AppColors.accentDark;',
          ))
            s.line,
        ],
        [1],
      );
    });

    test('are not tinted: a tint of one puts its label under 4.5', () {
      expect(
        tintedStatusSites('''
final a = AppColors.accentTextLight.withValues(alpha: 0.15);
final b = (isDark ? AppColors.warningDark : AppColors.warningTextLight).withValues(alpha: 0.1);
final c = AppColors.accentLight.withValues(alpha: 0.15);
final d = AppColors.warningLight.withValues(alpha: 0.15);
''').map((s) => s.line).toList(),
        [1, 2],
      );
    });
  });

  group('the bright blue and amber', () {
    List<int> found(String source) => [
      for (final s in brightSites(source)) s.line,
    ];

    test('are counted when read as a colour, in any theme branch', () {
      expect(
        found('''
final a = AppColors.accentLight;
final b = isDark ? AppColors.warningDark : AppColors.warningLight;
Text('x', style: TextStyle(color: AppColors.accentLight));
'''),
        [1, 2, 3],
      );
    });

    test('are not counted as a tint of half strength or less', () {
      expect(
        found('''
final a = AppColors.accentLight.withValues(alpha: 0.15);
final b = (isDark ? AppColors.warningDark : AppColors.warningLight).withValues(alpha: 0.5);
final c = AppColors.warningLight.withValues(alpha: 0.7);
final d = AppColors.accentLight.withAlpha(128);
'''),
        [3, 4],
      );
    });

    test('ignore the text colours, the dark colours, comments and strings', () {
      expect(
        found('''
final a = AppColors.accentTextLight;
final b = AppColors.warningDark;
// AppColors.accentLight in a comment
final c = 'AppColors.warningLight';
'''),
        isEmpty,
      );
    });
  });

  test(
    'the bright blue and amber are read only where a fill or tint needs them',
    () {
      final found = <String, int>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (_skipped.contains(path)) continue;
        final n = brightSites(entity.readAsStringSync()).length;
        if (n > 0) found[path] = n;
      }
      expect(
        found,
        _bright,
        reason:
            'A read of accentLight or warningLight that is not a tint is a fill. '
            'A text or an icon takes accentTextLight or warningTextLight in '
            'light. A new fill needs its file and count in _bright.',
      );
    },
  );

  test('every site that reads a light colour checks the theme', () {
    final failures = <String>[];
    final stale = <String>[];
    final seen = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (_skipped.contains(path)) continue;
      final sites = unguardedSites(entity.readAsStringSync());
      final allowed = _unfixed[path] ?? 0;
      if (allowed > 0) seen.add(path);
      if (sites.length == allowed) continue;
      if (sites.length < allowed) {
        stale.add('$path: ${sites.length} left, _unfixed says $allowed');
        continue;
      }
      failures.addAll([
        if (allowed > 0) '$path: ${sites.length} sites, _unfixed says $allowed',
        for (final s in sites)
          '$path:${s.line} AppColors.${s.constant}  ${s.expression}',
      ]);
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(stale, isEmpty, reason: 'Lower the count: ${stale.join('\n')}');
    expect(
      _unfixed.keys.toSet().difference(seen),
      isEmpty,
      reason: 'Delete the entry: the file is fixed or gone.',
    );
  });

  test(
    'no light colour is painted in the dark theme, nor the dark grey in the light',
    () {
      final reversed = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (_skipped.contains(path)) continue;
        for (final s in reversedSites(entity.readAsStringSync())) {
          reversed.add(
            '$path:${s.line} AppColors.${s.constant}  ${s.expression}',
          );
        }
      }
      expect(
        reversed,
        isEmpty,
        reason: 'The colour is in the wrong branch of the theme check.',
      );
    },
  );

  test('no tint is made of a status colour that got deeper', () {
    final tinted = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // The constants are defined here.
      if (path == 'lib/core/theme/app_colors.dart') continue;
      for (final s in tintedStatusSites(entity.readAsStringSync())) {
        final name = s.constant.contains('.')
            ? s.constant
            : 'AppColors.${s.constant}';
        tinted.add('$path:${s.line} $name  ${s.expression}');
      }
    }
    expect(
      tinted,
      isEmpty,
      reason:
          'Tint successTintLight, dangerTintLight, accentLight or warningLight: '
          'a tint of the deeper value puts text on it under 4.5:1.',
    );
  });

  group('the colour file', () {
    test('finds an alias of a listed constant that is not listed', () {
      expect(
        unlistedAliases('''
static const Color errorLight = dangerLight;
static const Color lossText = dangerLight;
static const Color deepLoss = lossText;
static const Color other = Color(0xFF000000);
static const Color same = successDark;
''', _constants),
        ['lossText', 'deepLoss'],
      );
    });

    test('lists every alias of a listed constant', () {
      expect(
        unlistedAliases(
          File('lib/core/theme/app_colors.dart').readAsStringSync(),
          _constants,
        ),
        isEmpty,
        reason: 'Add the alias to _constants: it paints the same light colour.',
      );
    });
  });

  test('the sites kept on a theme-neutral comment are the ones listed', () {
    final found = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (_skipped.contains(path)) continue;
      final n = neutralSites(entity.readAsStringSync()).length;
      if (n > 0) found[path] = n;
    }
    expect(
      found,
      _neutral,
      reason: 'A theme-neutral comment needs its file and count in _neutral.',
    );
  });
}
