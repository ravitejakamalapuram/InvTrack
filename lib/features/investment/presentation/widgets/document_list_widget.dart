/// Widget for displaying a list of documents attached to an investment.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/document_viewer_screen.dart';

/// Widget displaying documents for an investment with add/delete capabilities
class DocumentListWidget extends ConsumerWidget {
  final String investmentId;
  final bool isReadOnly;

  const DocumentListWidget({
    super.key,
    required this.investmentId,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final documentsAsync = ref.watch(
      documentsByInvestmentProvider(investmentId),
    );

    // Document list or empty state (header removed - using segmented control + FAB now)
    return documentsAsync.when(
      data: (documents) {
        if (documents.isEmpty) {
          return _buildEmptyState(isDark);
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          separatorBuilder: (context, index) => SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) => _DocumentCard(
            document: documents[index],
            isDark: isDark,
            isReadOnly: isReadOnly,
          ),
        );
      },
      loading: () => _buildEmptyState(
        isDark,
      ), // Show empty state while loading (offline friendly)
      error: (e, _) => _buildEmptyState(
        isDark,
      ), // Show empty state on error (offline friendly)
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 48,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.3,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No documents yet',
            style: AppTypography.body.copyWith(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.5,
              ),
            ),
          ),
          if (!isReadOnly) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              'Tap + to add receipts, contracts, or statements',
              style: AppTypography.caption.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.3,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Card displaying a single document with preview and actions
class _DocumentCard extends ConsumerWidget {
  final DocumentEntity document;
  final bool isDark;
  final bool isReadOnly;

  const _DocumentCard({
    required this.document,
    required this.isDark,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openDocument(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Thumbnail or icon
              _buildThumbnail(),
              SizedBox(width: AppSpacing.md),

              // Document info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? Colors.white
                            : AppColors.neutral900Light,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: document.type.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            document.type.displayName,
                            style: AppTypography.caption.copyWith(
                              color: document.type.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          document.fileSizeFormatted,
                          style: AppTypography.caption.copyWith(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatRelative(document.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              if (!isReadOnly)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.5,
                    ),
                  ),
                  onSelected: (value) => _handleMenuAction(context, ref, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (document.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(document.localPath),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildIconThumbnail(),
        ),
      );
    }
    return _buildIconThumbnail();
  }

  Widget _buildIconThumbnail() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: document.type.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        document.isPdf ? Icons.picture_as_pdf_rounded : document.type.icon,
        color: document.type.color,
        size: 24,
      ),
    );
  }

  void _openDocument(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(document: document),
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'view':
        _openDocument(context, ref);
        break;
      case 'delete':
        await _confirmDelete(context, ref);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(documentNotifierProvider).deleteDocument(document.id);
        if (context.mounted) {
          AppFeedback.showSuccess(context, 'Document deleted');
        }
      } catch (e) {
        if (context.mounted) {
          AppFeedback.showError(context, 'Failed to delete document');
        }
      }
    }
  }
}
