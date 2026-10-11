/// Tiles side by side that share a top and a height.
///
/// A `Row` centres its children, so a tile with one more line of text is taller
/// than its neighbour and the two tops end up apart (the Overview MOIC tile with
/// a duration line sat 6.5dp above the cash flows tile). `TileRow` gives its
/// tiles equal widths and stretches them to the tallest one, so every tile in a
/// row has the same top and the same height whatever it says.
///
/// Use it for cards that hold their own padding and decoration (a tile with an
/// icon and a text, a metric box). Figures that are a label over a value use
/// `StatColumns` (lib/core/widgets/stat_columns.dart), which also puts their
/// baselines on one line. `test/repo/card_alignment_scan_test.dart` lists the
/// cards that must use one of the two.
///
/// The tiles must not need a `LayoutBuilder` to size themselves: the height of
/// the row is the intrinsic height of its tallest tile.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

class TileRow extends StatelessWidget {
  const TileRow({super.key, required this.children, this.gap = AppSpacing.sm});

  /// The tiles, in reading order. They get equal widths.
  final List<Widget> children;

  /// Between two tiles.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
