import 'package:flutter/material.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Scrollable, searchable list of every supported currency. Returns the chosen
/// code, or null when dismissed.
Future<String?> showCurrencyPickerSheet(
  BuildContext context, {
  required String selected,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    builder: (_) => _CurrencyPickerSheet(selected: selected),
  );
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({required this.selected});

  final String selected;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim().toLowerCase();
    final currencies = LocaleDetectionService.getSupportedCurrencies().entries
        .where(
          (e) =>
              query.isEmpty ||
              e.key.toLowerCase().contains(query) ||
              e.value.toLowerCase().contains(query),
        )
        .toList();
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final muted = isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;
    final strong = isDark ? Colors.white : AppColors.neutral900Light;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  l10n.selectCurrency,
                  style: AppTypography.h2.copyWith(color: strong),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: l10n.searchCurrencies,
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final code = currencies[index].key;
                final isSelected = code == widget.selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.pop(context, code),
                    selected: isSelected,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.withValues(alpha: 0.2)
                                : (isDark
                                      ? AppColors.neutral800Dark
                                      : AppColors.neutral100Light),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              getCurrencySymbol(code),
                              style: AppTypography.h3.copyWith(
                                color: isSelected ? accent : muted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                code,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: strong,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencies[index].value,
                                style: AppTypography.caption.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: accent),
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
  }
}
