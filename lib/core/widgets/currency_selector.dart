import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCurrencyPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencies = LocaleDetectionService.getSupportedCurrencies();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filter currencies based on search query
          final filteredCurrencies = _searchQuery.isEmpty
              ? currencies
              : Map.fromEntries(
                  currencies.entries.where((entry) {
                    final code = entry.key.toLowerCase();
                    final name = entry.value.toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    return code.contains(query) || name.contains(query);
                  }),
                );

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.neutral600Dark
                                : AppColors.neutral300Light,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'Select Currency',
                        style: AppTypography.h2.copyWith(
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${filteredCurrencies.length} currencies available',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral500Light,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search currencies...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() => _searchQuery = value);
                        },
                      ),
                    ],
                  ),
                ),
                // Currency list
                Expanded(
                  child: ListView.builder(
                    padding: AppSpacing.screenPadding,
                    itemCount: filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final entry = filteredCurrencies.entries.elementAt(index);
                      final code = entry.key;
                      final name = entry.value;
                      final symbol = getCurrencySymbol(code);
                      final isSelected = code == widget.selectedCurrency;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            widget.onCurrencySelected(code);
                            Navigator.pop(context);
                          },
                          child: Row(
                          children: [
                            // Currency symbol
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                          ? AppColors.primaryDark.withOpacity(
                                              0.2,
                                            )
                                          : AppColors.primaryLight.withOpacity(
                                              0.2,
                                            ))
                                    : (isDark
                                          ? AppColors.neutral800Dark
                                          : AppColors.neutral100Light),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  symbol,
                                  style: AppTypography.h3.copyWith(
                                    color: isSelected
                                        ? (isDark
                                              ? AppColors.primaryDark
                                              : AppColors.primaryLight)
                                        : (isDark
                                              ? AppColors.neutral400Dark
                                              : AppColors.neutral500Light),
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
                                    code,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.neutral900Light,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    name,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark
                                          ? AppColors.neutral400Dark
                                          : AppColors.neutral500Light,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Selected indicator
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight,
                              ),
                          ],
                        ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
                      ? AppColors.primaryDark.withOpacity(0.2)
                      : AppColors.primaryLight.withOpacity(0.2),
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
