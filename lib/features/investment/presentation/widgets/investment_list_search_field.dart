/// Search field widget for the investment list screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Timer? _debounceTimer;
  bool _wasClearButtonVisible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Auto-focus when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // OPTIMIZATION: Only rebuild if the visibility of the clear button needs to change.
    // Previously, this called setState on every character change, causing
    // unnecessary rebuilds of the entire widget tree below this point.
    final shouldShow = _controller.text.isNotEmpty;
    if (_wasClearButtonVisible != shouldShow) {
      _wasClearButtonVisible = shouldShow;
      if (mounted) setState(() {});
    }
  }

  void _clearText() {
    _controller.clear();
    _onSearchChanged('');
    HapticFeedback.lightImpact();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    // Debounce the search input to avoid unnecessary filtering/sorting on every keystroke
    // which can be expensive (O(N) operations)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(investmentListStateProvider.notifier).setSearchQuery(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync state in case parent rebuilt us or initial state
    _wasClearButtonVisible = _controller.text.isNotEmpty;
    final showClearButton = _wasClearButtonVisible;

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
                suffixIcon: showClearButton
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral400Light,
                          size: 20,
                        ),
                        tooltip: 'Clear text',
                        onPressed: _clearText,
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        // Close button
        IconButton(
          icon: const Icon(Icons.close_rounded),
          iconSize: 20,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          tooltip: 'Close search',
          onPressed: () {
            ref.read(investmentListStateProvider.notifier).toggleSearch();
          },
        ),
      ],
    );
  }
}
