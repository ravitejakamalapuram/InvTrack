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
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

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
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    // Initialize state based on initial text
    _showClearButton = _controller.text.isNotEmpty;
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
    final shouldShow = _controller.text.isNotEmpty;
    // OPTIMIZATION: Only rebuild if the clear button visibility state actually changes.
    // Previously, this rebuilt the entire widget on every keystroke.
    if (_showClearButton != shouldShow) {
      setState(() {
        _showClearButton = shouldShow;
      });
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
    final l10n = AppLocalizations.of(context);
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
                hintText: l10n.hintSearch,
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
                suffixIcon: _showClearButton
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral400Light,
                          size: 20,
                        ),
                        tooltip: l10n.tooltipClearText,
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
