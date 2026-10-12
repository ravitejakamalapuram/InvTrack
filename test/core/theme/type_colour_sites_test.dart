// Source scan: where an investment, goal or document type's colour is read.
//
// A type's colour is a fill (the tile, the selected chip, the header). A name
// or an icon painted on a pale tint of it takes `InvestmentType.textColor` on
// `tintColor`, and a label or an icon painted on the fill itself takes
// `AppColors.onFill`; the bright fill as text is 1.4:1 to 4.3:1.
//
// This scan counts, per file, the reads of a `...type.color`. Each file's count
// is a literal below, so a new read, in a new file or an old one, shows in the
// diff of this test and a reviewer decides whether it is a fill. The reads that
// are not fills yet are listed apart in [_unjudged]; that list may only shrink.
//
// The scan reads text, not types. It sees `type.color`, `investment.type.color`
// and `selectedType.color`, not the same colour reached through another name
// (`t.color`, a variable). Widget tests that pump the screens read the real
// colours; this scan is the net under them.
//
// It also fails any `computeLuminance()` in lib/ outside `AppColors.onFill`:
// a threshold on luminance picks white on fills where it reads 1.4:1.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads that are a fill: the colour a TypeSelector paints its selected chip
/// with, the tile and the header of a type, and a border.
const _fills = <String, int>{
  // TypeSelector colorBuilder (the selected chip's fill; its label is onFill).
  'lib/features/goals/presentation/screens/create_goal_screen.dart': 1,
  'lib/features/investment/presentation/screens/add_investment_screen.dart': 2,
  'lib/features/investment/presentation/widgets/edit_document_sheet.dart': 1,
  'lib/features/investment/presentation/widgets/add_document_sheet.dart': 1,
  // The header's fill; everything on it is onFill of it.
  'lib/features/investment/presentation/screens/investment_detail_screen.dart':
      1,
  // The tile's gradient and shadow; its icon is onFill of the fill.
  'lib/features/investment/presentation/widgets/investment_card.dart': 1,
  // The border of the active filter chip.
  'lib/features/investment/presentation/screens/investment_list_screen.dart': 1,
  // The border of the selected chip.
  'lib/features/investment/presentation/widgets/merge_investments_dialog.dart':
      1,
};

/// Reads of a document type's colour as a text or an icon on a 15% or 30%
/// tint. The audit never judged them (about 2:1 to 4:1). They are not in this
/// PR's scope, which covers document types only through the TypeSelector chip;
/// they need the same `textColor` and `tintColor` as the investment types.
const _unjudged = <String, int>{
  'lib/features/investment/presentation/screens/document_viewer_screen.dart': 3,
  'lib/features/investment/presentation/widgets/add_document_sheet.dart': 8,
  'lib/features/investment/presentation/widgets/document_list_widget.dart': 4,
};

/// The one file that may call `computeLuminance()`: `AppColors.onFill`.
const _luminanceFiles = {'lib/core/theme/app_colors.dart'};

final _typeColourRead = RegExp(r'\b\w*[tT]ype\.color\b');

/// [source] without its comments, so a doc line that mentions `type.color`
/// does not count. A `//` inside a string is cut with the rest of its line,
/// which can only hide a read.
String stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp('//.*'), '');

int typeColourReads(String source) =>
    _typeColourRead.allMatches(stripComments(source)).length;

Map<String, int> _scan(int Function(String source) count) {
  final found = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    // The files that define the colours do not read them.
    if (path.endsWith('/investment_ui.dart') ||
        path.endsWith('/goal_type_ui.dart')) {
      continue;
    }
    final n = count(entity.readAsStringSync());
    if (n > 0) found[path] = n;
  }
  return found;
}

void main() {
  test('a type colour is read only where the list says it is a fill', () {
    final merged = <String, int>{};
    for (final map in [_fills, _unjudged]) {
      map.forEach((path, n) => merged[path] = (merged[path] ?? 0) + n);
    }
    expect(
      _scan(typeColourReads),
      merged,
      reason:
          'A name or an icon on a tint of a type takes '
          'type.textColor(brightness) on type.tintColor(brightness); a label '
          'on the fill takes AppColors.onFill(fill). A new fill needs its file '
          'and count in _fills.',
    );
  });

  test('no code outside AppColors.onFill thresholds on luminance', () {
    final found = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (stripComments(
        entity.readAsStringSync(),
      ).contains('computeLuminance(')) {
        found.add(path);
      }
    }
    expect(
      found,
      _luminanceFiles,
      reason:
          'Pick a label colour with AppColors.onFill(fill). A threshold on '
          'luminance sent white onto gold at 1.40:1.',
    );
  });

  group('the scan itself', () {
    test('counts the spellings it claims to', () {
      expect(typeColourReads('final c = type.color;'), 1);
      expect(typeColourReads('x(widget.investment.type.color)'), 1);
      expect(
        typeColourReads('x(file.selectedType.color, document.type.color)'),
        2,
      );
    });

    test('ignores a comment, a longer name and the new getters', () {
      expect(typeColourReads('// type.color is the fill'), 0);
      expect(typeColourReads('/* type.color */ final a = 1;'), 0);
      expect(typeColourReads('final c = type.textColor(b);'), 0);
      expect(typeColourReads('final c = type.tintColor(b);'), 0);
      expect(typeColourReads('final c = typeColor;'), 0);
    });
  });
}
