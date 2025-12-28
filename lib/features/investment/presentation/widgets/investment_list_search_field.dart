/// Search field widget for the investment list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Search field shown in the app bar when searching
class InvestmentListSearchField extends ConsumerStatefulWidget {
  const InvestmentListSearchField({super.key});

  @override
  ConsumerState<InvestmentListSearchField> createState() =>
      _InvestmentListSearchFieldState();
}

class _InvestmentListSearchFieldState
    extends ConsumerState<InvestmentListSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Search icon
        Icon(
          Icons.search_rounded,
          size: 20,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
        SizedBox(width: AppSpacing.sm),
        // Text field
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              cursorColor: isDark ? Colors.white70 : AppColors.primaryLight,
              style: AppTypography.body.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontSize: 16,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral500Light,
                  fontSize: 16,
                  height: 1.2,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                ref
                    .read(investmentListStateProvider.notifier)
                    .setSearchQuery(value);
              },
            ),
          ),
        ),
        // Close button
        GestureDetector(
          onTap: () {
            ref.read(investmentListStateProvider.notifier).toggleSearch();
          },
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
      ],
    );
  }
}
