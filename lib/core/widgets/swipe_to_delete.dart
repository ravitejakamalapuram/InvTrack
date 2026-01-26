/// Generic swipe-to-delete wrapper widget.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';

/// A reusable wrapper that adds swipe-to-delete functionality to any widget.
class SwipeToDelete extends StatelessWidget {
  /// Unique key for the dismissible (usually the item's id)
  final String itemKey;

  /// The child widget to wrap
  final Widget child;

  /// Title for the confirmation dialog
  final String confirmTitle;

  /// Message for the confirmation dialog
  final String confirmMessage;

  /// Callback when the item is dismissed
  final VoidCallback onDismissed;

  /// Success message to show after deletion
  final String successMessage;

  /// Whether swipe is enabled (disabled in selection mode)
  final bool enabled;

  const SwipeToDelete({
    super.key,
    required this.itemKey,
    required this.child,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onDismissed,
    required this.successMessage,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Dismissible(
      key: Key(itemKey),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: AppColors.dangerGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        onDismissed();
        AppFeedback.showSuccess(context, successMessage);
      },
      child: child,
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return AppFeedback.showConfirmDialog(
      context: context,
      title: confirmTitle,
      message: confirmMessage,
      confirmText: 'Delete',
    );
  }
}
