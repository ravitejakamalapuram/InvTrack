/// A card's line of content with something at its end: they share a line while
/// they fit, and at large text sizes the last child drops below the others
/// instead of overflowing.
///
/// A Row of `Expanded` and a fixed-width child cannot do this (the detail
/// screen's net position, current value, cash flow summary and maturity lines
/// all overflowed at large text). The children keep their natural widths; the
/// first starts on the start edge and, on a line of two or more, the last ends
/// on the end edge.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

class SpreadRow extends StatelessWidget {
  const SpreadRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        children: children,
      ),
    );
  }
}
