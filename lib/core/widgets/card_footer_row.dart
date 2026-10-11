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
/// When the longest word of the text does not fit beside the status (a large
/// text size on a narrow phone), the text goes under the status on the full
/// width, still end-aligned, so no word is broken in the middle.
///
/// The caller keeps its own padding and decoration, so the end of this row is
/// the card padding.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/text_measure.dart';

class CardFooterRow extends StatelessWidget {
  const CardFooterRow({
    super.key,
    required this.leadingIcon,
    required this.leadingText,
    required this.leadingStyle,
    required this.trailingText,
    required this.trailingStyle,
    this.iconSize = 14,
    this.iconGap = 6,
    this.gap = AppSpacing.sm,
  });

  /// The status: an icon and its label, at their natural width. The icon
  /// takes the colour of [leadingStyle], and the status lines up on the label's
  /// baseline.
  final IconData leadingIcon;
  final String leadingText;
  final TextStyle leadingStyle;

  /// The line on the end edge; empty draws nothing. A string, not a widget, so
  /// the alignment cannot be forgotten.
  final String trailingText;

  final TextStyle trailingStyle;

  final double iconSize;

  /// Between the icon and the label of the status.
  final double iconGap;

  /// The least space between the status and the text; also the space between
  /// them when the text goes under the status.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // The icon has no baseline of its own: the status is the label's.
        IgnoreBaseline(
          child: Icon(leadingIcon, size: iconSize, color: leadingStyle.color),
        ),
        SizedBox(width: iconGap),
        Flexible(child: Text(leadingText, style: leadingStyle)),
      ],
    );
    if (trailingText.isEmpty) return status;
    final message = Text(
      trailingText,
      textAlign: TextAlign.end,
      style: trailingStyle,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final statusWidth =
            iconSize +
            iconGap +
            measureTextWidth(context, leadingText, leadingStyle);
        var longestWord = 0.0;
        for (final word in trailingText.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          longestWord = math.max(
            longestWord,
            measureTextWidth(context, word, trailingStyle),
          );
        }
        final beside =
            statusWidth + gap + longestWord <= constraints.maxWidth + 0.01;
        if (beside) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              status,
              SizedBox(width: gap),
              Expanded(child: message),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: status),
            const SizedBox(height: AppSpacing.xxs),
            message,
          ],
        );
      },
    );
  }
}
