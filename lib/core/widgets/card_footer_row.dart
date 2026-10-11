/// The footer of a card: a status on the start edge and a line of text on the
/// end edge.
///
/// The text is end-aligned to the card padding, the same edge as the ring,
/// badge or amount above it, and it wraps instead of being cut. A Row of
/// `Spacer()` and `Flexible(Text)` cannot do this: both take half of the free
/// space, so the text starts half way and ends short of the padding by the
/// less it needs (the goal card footer ended 22 to 48dp short).
/// `test/repo/card_alignment_scan_test.dart` fails on that pattern.
///
/// The caller keeps its own padding and decoration, so the end of this row is
/// the card padding.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

class CardFooterRow extends StatelessWidget {
  const CardFooterRow({
    super.key,
    required this.leading,
    required this.trailingText,
    required this.trailingStyle,
    this.gap = AppSpacing.sm,
  });

  /// The status icon and its label, at their natural width. Put the icon in
  /// `IgnoreBaseline`, so the baseline of the status is the label's.
  final Widget leading;

  /// The line on the end edge; empty draws nothing. A string, not a widget, so
  /// the alignment cannot be forgotten.
  final String trailingText;

  final TextStyle trailingStyle;

  /// The least space between [leading] and the text.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        leading,
        if (trailingText.isNotEmpty) ...[
          SizedBox(width: gap),
          Expanded(
            child: Text(
              trailingText,
              textAlign: TextAlign.end,
              style: trailingStyle,
            ),
          ),
        ],
      ],
    );
  }
}
