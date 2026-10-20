import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/currency_picker_sheet.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

/// Currency selector widget for selecting a currency from supported currencies
///
/// **Features:**
/// - Shows all 40+ supported currencies
/// - Displays currency code, name, and symbol
/// - Search functionality for quick selection
/// - Grouped by region (Americas, Europe, Asia, Oceania, Africa)
/// - Highlights selected currency
///
/// **Usage:**
/// ```dart
/// CurrencySelector(
///   selectedCurrency: 'USD',
///   onCurrencySelected: (code) => setState(() => _currency = code),
///   label: 'Investment Currency',
///   subtitle: 'Select the currency for this investment',
/// )
/// ```
class CurrencySelector extends StatefulWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencySelected;
  final String? label;
  final String? subtitle;

  const CurrencySelector({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencySelected,
    this.label,
    this.subtitle,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  Future<void> _showCurrencyPicker(BuildContext context) async {
    final code = await showCurrencyPickerSheet(
      context,
      selected: widget.selectedCurrency,
    );
    if (code != null) widget.onCurrencySelected(code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = getCurrencySymbol(widget.selectedCurrency);
    final currencies = LocaleDetectionService.getSupportedCurrencies();
    final currencyName =
        currencies[widget.selectedCurrency] ?? widget.selectedCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (widget.subtitle != null) ...[
          Text(
            widget.subtitle!,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          const SizedBox(height: 12),
        ],
        GlassCard(
          padding: const EdgeInsets.all(16),
          onTap: () => _showCurrencyPicker(context),
          child: Row(
            children: [
              // Currency symbol
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryDark.withValues(alpha: 0.2)
                      : AppColors.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: AppTypography.h3.copyWith(
                      color: isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Currency info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selectedCurrency,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.neutral900Light,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyName,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                      ),
                    ),
                  ],
                ),
              ),
              // Dropdown icon
              Icon(
                Icons.arrow_drop_down_rounded,
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
