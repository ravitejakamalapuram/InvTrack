/// Equal columns of label over value, with one baseline for the labels and one
/// for the values.
///
/// Every card that shows two or three figures side by side (the Overview hero:
/// out, in, XIRR; the Investment detail: XIRR and MOIC) lays them out with
/// this widget, so the same rules hold everywhere and cannot drift per card:
///
///  * The columns are equal in width. The first starts on the start edge and
///    the last ends on the end edge ([StatColumnsAlign.edges]), or every
///    column is centred ([StatColumnsAlign.center]). Both mirror in
///    right-to-left layouts.
///  * The values of one row share a baseline, and so do the labels, whatever
///    the sizes of the values. A label that wraps grows upward, and a note
///    goes below its own value, so nothing a column adds can move its value.
///  * A screen reader reads each column as one stop: "labelText:", then the
///    value (with its own hint and actions), then the note. The label and the
///    note are drawn but not read on their own; a [StatColumn.semanticsLabel]
///    replaces the whole stop.
///  * When a column would get less than `minColumnWidth` (scaled by the text
///    size), the row drops to fewer columns. A column left alone is a line
///    of "label ..... value", the value on the end edge.
///  * Nothing is ever cut: labels wrap, columns stack.
///
/// The widget only places what it is given; the callers keep their own text
/// styles and colours. `test/layout/card_guard_*_test.dart` measures it in the
/// real cards, `test/core/widgets/stat_columns_test.dart` on its own, and the
/// rules are written down in design/system/README.md ("Card alignment").
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/text_scale.dart';

/// One figure: a [label] over a [value], and an optional [note] under it.
class StatColumn {
  const StatColumn({
    required this.label,
    required this.labelText,
    required this.value,
    this.note,
    this.semanticsLabel,
  });

  /// May wrap onto several lines. Put an icon in front of the text with
  /// `IgnoreBaseline`, so the baseline of the label stays the text's.
  final Widget label;

  /// What [label] says, for a screen reader: it reads "labelText: value, note"
  /// as one stop. The label itself is not read, so an icon or a style in it
  /// cannot add a stop of its own.
  final String labelText;

  /// One line, unless it is a long phrase that has to wrap.
  final Widget value;

  /// Under its own value. It never moves the value.
  final Widget? note;

  /// What a screen reader says instead of the label, value and note, for a
  /// figure that needs more words than it shows.
  final String? semanticsLabel;
}

enum StatColumnsAlign {
  /// The first column starts on the start edge, the last ends on the end edge.
  edges,

  /// Every column is centred in its width.
  center,
}

class StatColumns extends StatelessWidget {
  const StatColumns({
    super.key,
    required this.columns,
    this.align = StatColumnsAlign.edges,
    this.gap = AppSpacing.xs,
    this.labelGap = AppSpacing.xxs,
    this.maxPerRow = 3,
    this.minColumnWidth,
    this.tileBuilder,
    this.tilePadding = EdgeInsets.zero,
  });

  final List<StatColumn> columns;
  final StatColumnsAlign align;

  /// Between columns, and between rows when the columns stack.
  final double gap;

  /// Between a label and its value.
  final double labelGap;

  final int maxPerRow;

  /// The narrowest a column may get at text x1.0 (it scales with the text
  /// size) before the row drops to fewer columns; null never stacks, for
  /// tiles whose labels wrap instead.
  final double? minColumnWidth;

  /// Builds the card behind column `index`. The cards of one row share a top
  /// and a height, whatever their content.
  final Widget Function(BuildContext context, int index)? tileBuilder;

  /// The space between a tile's edge and its content.
  final EdgeInsetsGeometry tilePadding;

  /// The key of the label of column [index], which has the column's width: for
  /// tests that measure the columns.
  static ValueKey<String> cellKey(int index) => ValueKey('stat-column-$index');

  /// The key of the value of column [index], which has the column's width.
  static ValueKey<String> valueKey(int index) => ValueKey('stat-value-$index');

  /// How many columns fit one row of [width]: all of them (up to
  /// [maxPerRow]), fewer while a column would be narrower than
  /// [minColumnWidth] x [textScale].
  static int columnsPerRow({
    required double width,
    required int count,
    required double gap,
    required int maxPerRow,
    required double? minColumnWidth,
    required double textScale,
  }) {
    var n = math.max(1, math.min(count, maxPerRow));
    if (minColumnWidth == null) return n;
    final least = minColumnWidth * textScale;
    while (n > 1 && (width - (n - 1) * gap) / n < least) {
      n--;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.hasBoundedWidth
              ? columnsPerRow(
                  width: constraints.maxWidth,
                  count: columns.length,
                  gap: gap,
                  maxPerRow: maxPerRow,
                  minColumnWidth: minColumnWidth,
                  textScale: textScaleOf(context),
                )
              : math.max(1, math.min(columns.length, maxPerRow));
          final rows = <Widget>[];
          for (var start = 0; start < columns.length; start += perRow) {
            final end = math.min(start + perRow, columns.length);
            if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
            rows.add(
              end - start == 1
                  ? _InlineRow(
                      column: columns[start],
                      index: start,
                      gap: gap,
                      width: constraints.maxWidth,
                      tile: tileBuilder,
                      tilePadding: tilePadding,
                    )
                  : _ColumnsRow(
                      columns: columns.sublist(start, end),
                      firstIndex: start,
                      align: align,
                      gap: gap,
                      labelGap: labelGap,
                      tile: tileBuilder,
                      tilePadding: tilePadding,
                    ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
        },
      ),
    );
  }
}

/// Two or more columns side by side, in two bands so that each kind of line
/// has one baseline across the row whatever the font sizes: the labels share
/// their last line (a label that wraps grows upward) and the values share one
/// baseline. A note sits under its own value.
///
/// For a screen reader each column is one stop, "label:" then the value, then
/// the note: the label and the note are drawn but not read on their own, and
/// the value (with its own hint and actions) is merged with them in one node.
class _ColumnsRow extends StatelessWidget {
  const _ColumnsRow({
    required this.columns,
    required this.firstIndex,
    required this.align,
    required this.gap,
    required this.labelGap,
    required this.tile,
    required this.tilePadding,
  });

  final List<StatColumn> columns;
  final int firstIndex;
  final StatColumnsAlign align;
  final double gap;
  final double labelGap;
  final Widget Function(BuildContext, int)? tile;
  final EdgeInsetsGeometry tilePadding;

  @override
  Widget build(BuildContext context) {
    final n = columns.length;
    final padding = tilePadding.resolve(Directionality.of(context));
    final sides = EdgeInsets.only(left: padding.left, right: padding.right);

    AlignmentGeometry alignmentOf(int k) => align == StatColumnsAlign.center
        ? Alignment.center
        : k == n - 1
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    TextAlign textAlignOf(int k) => align == StatColumnsAlign.center
        ? TextAlign.center
        : k == n - 1
        ? TextAlign.end
        : TextAlign.start;

    // One part of column k on its side of the column.
    Widget part(int k, Widget child) => Align(
      alignment: alignmentOf(k),
      child: DefaultTextStyle.merge(textAlign: textAlignOf(k), child: child),
    );

    // One band: a column per Expanded.
    Widget band(CrossAxisAlignment cross, Widget Function(int k) cell) {
      return Row(
        crossAxisAlignment: cross,
        textBaseline: cross == CrossAxisAlignment.baseline
            ? TextBaseline.alphabetic
            : null,
        children: [
          for (var k = 0; k < n; k++) ...[
            if (k > 0) SizedBox(width: gap),
            Expanded(
              child: Padding(padding: sides, child: cell(k)),
            ),
          ],
        ],
      );
    }

    Widget labelCell(int k) => ExcludeSemantics(
      child: KeyedSubtree(
        key: StatColumns.cellKey(firstIndex + k),
        child: part(k, columns[k].label),
      ),
    );

    // The value and its note, with the label's words in front: the one stop of
    // the column. Its first baseline is the value's.
    Widget valueCell(int k) {
      final column = columns[k];
      final note = column.note;
      return _stop(
        column,
        firstIndex + k,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(
              key: StatColumns.valueKey(firstIndex + k),
              child: part(k, column.value),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: part(k, note),
              ),
          ],
        ),
      );
    }

    final bands = Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          band(CrossAxisAlignment.end, labelCell),
          SizedBox(height: labelGap),
          band(CrossAxisAlignment.baseline, valueCell),
        ],
      ),
    );
    final row = Semantics(
      container: true,
      explicitChildNodes: true,
      child: bands,
    );
    final build = tile;
    if (build == null) return row;
    // The cards sit behind the bands and are stretched to the height of the
    // row, so they share a top and a height whatever the columns hold.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < n; k++) ...[
                if (k > 0) SizedBox(width: gap),
                Expanded(child: build(context, firstIndex + k)),
              ],
            ],
          ),
        ),
        row,
      ],
    );
  }
}

/// The one screen reader stop of [column]: "labelText:" and then what [cell]
/// (the value, its hint and actions, and the note) says, or the column's own
/// [StatColumn.semanticsLabel] instead of all of it. The label widget is drawn
/// but kept out of the reading by the caller. The stops are read in the order
/// of [index], whatever the reading direction puts on the left.
Widget _stop(StatColumn column, int index, Widget cell) {
  final description = column.semanticsLabel;
  return Semantics(
    container: true,
    sortKey: OrdinalSortKey(index.toDouble()),
    label: description ?? '${column.labelText}:',
    excludeSemantics: description != null,
    child: cell,
  );
}

/// A column that has a row to itself: "label ..... value" on one baseline,
/// the value on the end edge.
class _InlineRow extends StatelessWidget {
  const _InlineRow({
    required this.column,
    required this.index,
    required this.gap,
    required this.width,
    required this.tile,
    required this.tilePadding,
  });

  /// The most of the row a value may take, so a long label still gets room.
  static const _valueShare = 0.65;

  final StatColumn column;
  final int index;
  final double gap;
  final double width;
  final Widget Function(BuildContext, int)? tile;
  final EdgeInsetsGeometry tilePadding;

  @override
  Widget build(BuildContext context) {
    final note = column.note;
    final body = Padding(
      padding: tilePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.start,
                    child: ExcludeSemantics(child: column.label),
                  ),
                ),
              ),
              SizedBox(width: gap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * _valueShare),
                child: KeyedSubtree(
                  key: StatColumns.valueKey(index),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.end,
                    child: column.value,
                  ),
                ),
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: DefaultTextStyle.merge(
                  textAlign: TextAlign.end,
                  child: note,
                ),
              ),
            ),
        ],
      ),
    );
    final build = tile;
    final framed = build == null
        ? body
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: build(context, index)),
              body,
            ],
          );
    return KeyedSubtree(
      key: StatColumns.cellKey(index),
      child: _stop(column, index, framed),
    );
  }
}
