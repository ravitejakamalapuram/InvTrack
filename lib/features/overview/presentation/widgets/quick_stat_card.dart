/// Quick stat card widget for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';

/// A card displaying a quick stat with icon, label, value, and optional subtitle.
class QuickStatCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
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
    this.subtitle,
    this.isSensitive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final shouldMask = isSensitive && isPrivacyMode;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
