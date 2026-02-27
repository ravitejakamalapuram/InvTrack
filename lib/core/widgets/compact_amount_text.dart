import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

/// A text widget that displays amounts in compact format (e.g., ₹1.05Cr)
/// with long-press to reveal full amount and copy functionality.
///
/// Automatically respects privacy mode - shows masked text when privacy is enabled.
///
/// Usage:
/// ```dart
/// CompactAmountText(
///   amount: 10505000,
///   compactText: '₹1.05Cr',
///   style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
/// )
/// ```
class CompactAmountText extends ConsumerWidget {
  /// The actual numeric amount (used for formatting full value)
  final double amount;

  /// The compact text to display (e.g., "₹1.05Cr")
  final String compactText;

  /// Text style for the compact display
  final TextStyle? style;

  /// Currency symbol for full formatting
  final String currencySymbol;

  /// Maximum lines for the text
  final int? maxLines;

  /// Text overflow behavior
  final TextOverflow? overflow;

  /// Text alignment
  final TextAlign? textAlign;

  /// Optional prefix (e.g., "+" or "-")
  final String? prefix;

  const CompactAmountText({
    super.key,
    required this.amount,
    required this.compactText,
    this.style,
    this.currencySymbol = '₹',
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.prefix,
  });

  String _fullFormattedAmount(WidgetRef ref) {
    final locale = ref.watch(currencyLocaleProvider);
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol,
      decimalDigits: 2,
    );
    final formatted = formatter.format(amount.abs());
    if (amount < 0) {
      return '-$formatted';
    }
    return formatted;
  }

  String get _displayText =>
      prefix != null ? '$prefix$compactText' : compactText;

  void _showFullAmount(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullAmount = _fullFormattedAmount(ref);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exact Amount',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prefix != null ? '$prefix$fullAmount' : fullAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: prefix != null ? '$prefix$fullAmount' : fullAmount,
                  ),
                );
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Copied to clipboard'),
                      ],
                    ),
                    backgroundColor: AppColors.successLight,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy',
            ),
          ],
        ),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.neutral800Light,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    if (isPrivacyMode) {
      return Semantics(
        label: 'Hidden amount',
        excludeSemantics: true,
        child: Text(
          '•••••',
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      );
    }

    return Semantics(
      label: AccessibilityUtils.formatCurrencyForScreenReader(
        amount,
        currencySymbol,
      ),
      hint: 'Double tap and hold to copy exact amount',
      onLongPress: () => _showFullAmount(context, ref),
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: () => _showFullAmount(context, ref),
        child: Text(
          _displayText,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      ),
    );
  }
}
