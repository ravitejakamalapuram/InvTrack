/// Generic swipe actions wrapper widget supporting delete and archive.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';

/// Configuration for archive action
class ArchiveActionConfig {
  /// Title for the confirmation dialog
  final String confirmTitle;

  /// Message for the confirmation dialog
  final String confirmMessage;

  /// Callback when the item is archived
  final VoidCallback onArchive;

  /// Success message to show after archiving
  final String successMessage;

  /// Whether the item is currently archived (for unarchive action)
  final bool isArchived;

  const ArchiveActionConfig({
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onArchive,
    required this.successMessage,
    this.isArchived = false,
  });
}

/// Configuration for delete action
class DeleteActionConfig {
  /// Title for the confirmation dialog
  final String confirmTitle;

  /// Message for the confirmation dialog
  final String confirmMessage;

  /// Callback when the item is deleted
  final VoidCallback onDelete;

  /// Success message to show after deletion
  final String successMessage;

  const DeleteActionConfig({
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onDelete,
    required this.successMessage,
  });
}

/// A reusable wrapper that adds swipe actions (delete and/or archive) to any widget.
///
/// - Swipe left to delete (endToStart direction)
/// - Swipe right to archive/unarchive (startToEnd direction)
class SwipeActions extends StatelessWidget {
  /// Unique key for the dismissible (usually the item's id)
  final String itemKey;

  /// The child widget to wrap
  final Widget child;

  /// Configuration for delete action (swipe left), null to disable
  final DeleteActionConfig? deleteConfig;

  /// Configuration for archive action (swipe right), null to disable
  final ArchiveActionConfig? archiveConfig;

  /// Whether swipe actions are enabled (disabled in selection mode)
  final bool enabled;

  const SwipeActions({
    super.key,
    required this.itemKey,
    required this.child,
    this.deleteConfig,
    this.archiveConfig,
    this.enabled = true,
  });

  DismissDirection get _direction {
    if (deleteConfig != null && archiveConfig != null) {
      return DismissDirection.horizontal;
    } else if (deleteConfig != null) {
      return DismissDirection.endToStart;
    } else if (archiveConfig != null) {
      return DismissDirection.startToEnd;
    }
    return DismissDirection.none;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled || (deleteConfig == null && archiveConfig == null)) {
      return child;
    }

    return Dismissible(
      key: Key(itemKey),
      direction: _direction,
      background: archiveConfig != null ? _buildArchiveBackground() : null,
      secondaryBackground:
          deleteConfig != null ? _buildDeleteBackground() : null,
      confirmDismiss: (direction) => _confirmDismiss(context, direction),
      onDismissed: (direction) => _onDismissed(context, direction),
      child: child,
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.dangerGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }

  Widget _buildArchiveBackground() {
    final isArchived = archiveConfig?.isArchived ?? false;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: isArchived ? AppColors.successGradient : AppColors.archiveGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      child: Icon(
        isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        color: Colors.white,
      ),
    );
  }

  Future<bool?> _confirmDismiss(
    BuildContext context,
    DismissDirection direction,
  ) async {
    HapticFeedback.mediumImpact();
    if (direction == DismissDirection.endToStart && deleteConfig != null) {
      return AppFeedback.showConfirmDialog(
        context: context,
        title: deleteConfig!.confirmTitle,
        message: deleteConfig!.confirmMessage,
        confirmText: 'Delete',
      );
    } else if (direction == DismissDirection.startToEnd &&
        archiveConfig != null) {
      final isArchived = archiveConfig!.isArchived;
      return AppFeedback.showConfirmDialog(
        context: context,
        title: archiveConfig!.confirmTitle,
        message: archiveConfig!.confirmMessage,
        confirmText: isArchived ? 'Unarchive' : 'Archive',
      );
    }
    return false;
  }

  void _onDismissed(BuildContext context, DismissDirection direction) {
    if (direction == DismissDirection.endToStart && deleteConfig != null) {
      deleteConfig!.onDelete();
      AppFeedback.showSuccess(context, deleteConfig!.successMessage);
    } else if (direction == DismissDirection.startToEnd &&
        archiveConfig != null) {
      archiveConfig!.onArchive();
      AppFeedback.showSuccess(context, archiveConfig!.successMessage);
    }
  }
}

