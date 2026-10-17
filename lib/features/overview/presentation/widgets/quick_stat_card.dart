/// Quick stat card widget for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// A card displaying a quick stat with icon, label, value, and optional subtitle.
class QuickStatCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// The colour the icon disc is tinted with, or null for [color]. A status
  /// colour that got deeper for text tints with its brighter hue.
  final Color? tint;
  final String? subtitle;

  /// Whether this value should be masked in privacy mode.
  /// Defaults to true for financial values.
  final bool isSensitive;

  const QuickStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.tint,
    this.subtitle,
    this.isSensitive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final shouldMask = isSensitive && isPrivacyMode;

    // Accessibility: Group all text elements into a single cohesive announcement.
    // Instead of reading "Label", "Value", "Subtitle" separately, screen readers will
    // announce "Label: Value, Subtitle". This reduces swipe fatigue.
    // Note: We hide subtitle in privacy mode to prevent leaking sensitive info.
    final semanticValue = shouldMask
        ? AppLocalizations.of(context).hiddenAmount
        : value;
    final showSubtitle = subtitle != null && !shouldMask;
    final semanticLabel =
        '$label: $semanticValue${showSubtitle ? ", $subtitle" : ""}';

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (tint ?? color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                      fontSize: 12,
                    ),
                  ),
                  shouldMask
                      ? MaskedAmountText(
                          text: value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                  if (subtitle != null)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: shouldMask ? 0.0 : 1.0,
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.neutral500Dark
                              : AppColors.neutral400Light,
                          fontSize: 11,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
