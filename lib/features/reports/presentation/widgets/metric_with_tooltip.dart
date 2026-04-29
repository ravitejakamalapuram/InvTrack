/// Metric label with tooltip widget
library;

import 'package:flutter/material.dart';

/// Displays a metric label with an info icon that shows a tooltip on tap
///
/// Example:
/// ```dart
/// MetricWithTooltip(
///   label: 'XIRR',
///   tooltip: l10n.xirrTooltip,
/// )
/// ```
class MetricWithTooltip extends StatelessWidget {
  /// The metric label text
  final String label;

  /// The tooltip message explaining the metric
  final String tooltip;

  /// Optional text style for the label
  final TextStyle? labelStyle;

  /// Optional icon size (default: 16)
  final double iconSize;

  /// Optional icon color
  final Color? iconColor;

  const MetricWithTooltip({
    required this.label,
    required this.tooltip,
    this.labelStyle,
    this.iconSize = 16,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: tooltip,
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 5),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
            fontSize: 13,
          ),
          child: Icon(
            Icons.help_outline_rounded,
            size: iconSize,
            color: iconColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
