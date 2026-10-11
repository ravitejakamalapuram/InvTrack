/// A card footer is `CardFooterRow` (lib/core/widgets/card_footer_row.dart),
/// not a Row of `Spacer()` and `Flexible(Text)`.
///
/// `Spacer` and `Flexible` both have flex 1, so such a Row gives the text only
/// the end half of the free space and starts it there: the shorter the text,
/// the further its end sits from the card padding (the goal card footer ended
/// 22 to 48dp short of the progress ring above it). The geometry test
/// (test/layout/card_guard_*_test.dart) measures the real cards; this plain
/// file check, like platforms_test.dart, stops the pattern from coming back in
/// a card nobody measures yet.
///
/// Code, not comments or strings, is what counts, as in the FAB clearance scan.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'fab_clearance_scan_test.dart'
    show libDartFiles, stripCommentsAndStrings;

/// Cards that lay figures out side by side, a footer, or tiles in a row, and
/// the shared widget (lib/core/widgets) each one must use. A new card of that
/// shape is added here, with the widget, in the PR that adds it.
const mustUse = <String, List<String>>{
  'lib/features/overview/presentation/widgets/hero_card.dart': ['StatColumns'],
  'lib/features/overview/presentation/screens/overview_screen.dart': [
    'StatColumns',
  ],
  'lib/features/investment/presentation/widgets/investment_detail_stats_section.dart':
      ['StatColumns'],
  'lib/features/goals/presentation/widgets/goal_card.dart': ['CardFooterRow'],
  'lib/features/overview/presentation/widgets/overview_quick_stats.dart': [
    'TileRow',
  ],
  'lib/features/income_projection/presentation/screens/income_trend_report_screen.dart':
      ['TileRow'],
};

final _spacer = RegExp(r'\bSpacer\s*\(');

/// What takes a share of the free space beside a `Spacer()`: a `Flexible(`, or
/// an `Expanded(` around a text (an optional `flex:` first). Both split the
/// space with the Spacer, so the text starts half way.
final _sibling = RegExp(
  r'\bFlexible\s*\('
  r'|\bExpanded\s*\(\s*(?:flex\s*:\s*\d+\s*,\s*)?child\s*:\s*(?:const\s+)?'
  r'(?:Text|MaskedAmountText|CompactAmountText)\b',
);

/// How many lines after a `Spacer(` a sibling still counts as being in the
/// same Row.
const _window = 12;

/// Files that may keep the pair, by path, each with the reason. Empty today;
/// adding a path needs a reason next to it.
const _allowed = <String, String>{};

String _problem(String path, int line, int siblingLine, String sibling) =>
    '$path:$line has Spacer() and, ${siblingLine - line} lines later, '
    '${sibling.trimRight()}. In a Row both take half of the free space, so '
    'the text starts half way and ends short of the card padding. Use '
    'CardFooterRow (lib/core/widgets/card_footer_row.dart), or allow the file '
    'in test/repo/card_alignment_scan_test.dart with a reason.';

/// Whether [path] holds cards or widgets that cards are built from.
bool _scanned(String path) =>
    path.contains('/presentation/') || path.startsWith('lib/core/widgets/');

/// Every Spacer-then-Flexible (or Spacer-then-Expanded-text) pair in the
/// presentation files and core widgets of [sources] (raw file text by
/// `/`-separated path).
List<String> spacerFlexibleProblems(Map<String, String> sources) {
  final problems = <String>[];
  for (final entry in sources.entries) {
    final path = entry.key;
    if (!_scanned(path) || _allowed.containsKey(path)) continue;
    final lines = stripCommentsAndStrings(entry.value).split('\n');
    for (var i = 0; i < lines.length; i++) {
      final spacer = _spacer.firstMatch(lines[i]);
      if (spacer == null) continue;
      // On the Spacer's own line only what comes after it counts.
      final text = [
        lines[i].substring(spacer.end),
        ...lines.sublist(i + 1, math.min(lines.length, i + _window + 1)),
      ].join('\n');
      final hit = _sibling.firstMatch(text);
      if (hit == null) continue;
      final line = i + 1 + '\n'.allMatches(text.substring(0, hit.start)).length;
      problems.add(_problem(path, i + 1, line, hit.group(0)!));
    }
  }
  return problems;
}

void main() {
  late final Map<String, String> sources;

  setUpAll(() {
    sources = {
      for (final path in libDartFiles()) path: File(path).readAsStringSync(),
    };
  });

  test('no presentation file lays a footer out as Spacer and Flexible', () {
    final problems = spacerFlexibleProblems(sources);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('controls: the scan sees the goal card, which uses CardFooterRow', () {
    const goalCard = 'lib/features/goals/presentation/widgets/goal_card.dart';
    expect(sources.keys, contains(goalCard), reason: 'the scan lost $goalCard');
    expect(
      stripCommentsAndStrings(sources[goalCard]!),
      contains('CardFooterRow('),
      reason: 'the goal card no longer lays its footer out with CardFooterRow',
    );
  });

  test(
    'the cards in the registry lay their figures out with the shared widget',
    () {
      for (final entry in mustUse.entries) {
        expect(
          sources.keys,
          contains(entry.key),
          reason: 'the scan lost ${entry.key}',
        );
        final code = stripCommentsAndStrings(sources[entry.key]!);
        for (final widget in entry.value) {
          expect(
            code,
            contains('$widget('),
            reason:
                '${entry.key} no longer uses $widget: figures side by side '
                'go in StatColumns, a footer in CardFooterRow and tiles that '
                'sit in a row in TileRow, so the alignment rules hold. Add a '
                'new card to mustUse in test/repo/card_alignment_scan_test.dart.',
          );
        }
      }
    },
  );

  test('every allowed file exists and says why', () {
    for (final entry in _allowed.entries) {
      expect(sources.keys, contains(entry.key));
      expect(entry.value.trim(), isNotEmpty);
    }
  });

  group('scanner', () {
    const widgets = 'lib/features/zz/presentation/widgets';

    List<String> scan(String source, {String path = '$widgets/a.dart'}) =>
        spacerFlexibleProblems({path: source});

    test('finds the pair in the same Row', () {
      expect(
        scan('''
Row(children: [
  Text('a'),
  const Spacer(),
  Flexible(child: Text('b')),
]);
'''),
        hasLength(1),
      );
    });

    test('finds a Spacer with a flex and a Flexible on the same line', () {
      expect(
        scan('Row(children: [Spacer(flex: 2), Flexible(child: x)]);'),
        hasLength(1),
      );
    });

    test('finds the pair 12 lines apart, not 13', () {
      // The numbers are written out, so the window cannot be changed without
      // changing this test.
      String gap(int lines) =>
          'Spacer(),\n${'x,\n' * (lines - 1)}Flexible(child: x),';
      expect(scan(gap(12)), hasLength(1));
      expect(scan(gap(13)), isEmpty);
    });

    test('a comment or a string that names the pair does not count', () {
      expect(
        scan('''
// Spacer() then Flexible(
/* Spacer(), Flexible( */
const a = 'Spacer() Flexible(';
'''),
        isEmpty,
      );
    });

    test('Expanded, a Flexible before the Spacer and a lone Spacer pass', () {
      expect(
        scan('Row(children: [Text(a), Spacer(), Expanded(child: b)]);'),
        isEmpty,
      );
      expect(
        scan('Row(children: [Flexible(child: a), Spacer(), Text(b)]);'),
        isEmpty,
      );
      expect(
        scan('Row(children: [Text(a), const Spacer(), Icon(b)]);'),
        isEmpty,
      );
    });

    test(
      'finds Spacer and Expanded around a text: it splits the space too',
      () {
        expect(
          scan('''
Row(children: [
  Icon(a),
  const Spacer(),
  Expanded(
    child: Text('b', textAlign: TextAlign.end),
  ),
]);
'''),
          hasLength(1),
        );
        expect(
          scan('Row(children: [Spacer(), Expanded(flex: 2, child: Text(b))]);'),
          hasLength(1),
        );
        expect(
          scan(
            'Row(children: [Spacer(), Expanded(child: MaskedAmountText(b))]);',
          ),
          hasLength(1),
        );
      },
    );

    test('Spacer and an Expanded around something else pass', () {
      expect(
        scan(
          'Row(children: [Spacer(), Expanded(child: Column(children: x))]);',
        ),
        isEmpty,
      );
    });

    test('a file outside presentation and core widgets is not scanned', () {
      expect(
        scan('Spacer(),\nFlexible(child: x),', path: 'lib/core/utils/a.dart'),
        isEmpty,
      );
      expect(
        scan('Spacer(),\nFlexible(child: x),', path: 'lib/data/a.dart'),
        isEmpty,
      );
    });

    test('a shared widget in core is scanned like a card', () {
      expect(
        scan('Spacer(),\nFlexible(child: x),', path: 'lib/core/widgets/a.dart'),
        hasLength(1),
      );
    });

    test('a name that only ends in Spacer or Flexible does not count', () {
      expect(scan('NoSpacer(),\nInflexible(child: x),'), isEmpty);
    });
  });
}
