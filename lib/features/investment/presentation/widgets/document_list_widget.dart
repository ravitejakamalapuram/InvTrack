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
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/edit_document_sheet.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
            l10n: l10n,
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

/// Card displaying a single document with swipe actions
class _DocumentCard extends ConsumerWidget {
  final DocumentEntity document;
  final bool isDark;
  final bool isReadOnly;
  final AppLocalizations l10n;

  const _DocumentCard({
    required this.document,
    required this.isDark,
    required this.isReadOnly,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardContent = Material(
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

              // Swipe hint icon (subtle indicator for swipe actions)
              if (!isReadOnly)
                Icon(
                  Icons.swipe_rounded,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );

    // If read-only, return card without swipe actions
    if (isReadOnly) {
      return cardContent;
    }

    // Wrap in Dismissible for swipe actions
    return Dismissible(
      key: Key(document.id),
      direction: DismissDirection.horizontal,
      // Swipe right (startToEnd) - Edit action
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              l10n.edit,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      // Swipe left (endToStart) - Delete action
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          gradient: AppColors.dangerGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.delete,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.selectionClick();
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Open edit sheet
          _showEditSheet(context, ref);
          return false; // Don't dismiss, just open edit
        } else {
          // Swipe left - Confirm delete
          return _confirmDeleteSwipe(context);
        }
      },
      onDismissed: (direction) async {
        // Only called for delete action (after confirmation)
        try {
          await ref.read(documentNotifierProvider).deleteDocument(document.id);
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            AppFeedback.showSuccess(context, l10n.documentDeleted);
          }
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            AppFeedback.showError(context, l10n.failedToDeleteDocument);
          }
        }
      },
      child: cardContent,
    );
  }

  /// Confirm delete via swipe - uses AppFeedback for consistency
  Future<bool> _confirmDeleteSwipe(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: l10n.deleteDocument,
      message: l10n.deleteDocumentMessage(document.name),
      confirmText: l10n.delete,
    );
    return confirmed;
  }

  Widget _buildThumbnail() {
    if (document.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(document.localPath),
          width: 48,
          height: 48,
          // OPTIMIZATION: Resize image to thumbnail size to save memory.
          // Without this, full resolution images (e.g. 12MP photos) are decoded
          // into memory even for this tiny 48x48 box, causing massive memory usage.
          cacheWidth: 150, // ~3x the display size for high-DPI screens
          fit: BoxFit.cover,
          semanticLabel: 'Document thumbnail: ${document.name}',
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

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditDocumentSheet(document: document),
    );
  }
}
