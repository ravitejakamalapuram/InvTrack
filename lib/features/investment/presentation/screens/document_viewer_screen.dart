/// Screen for viewing a document (image or PDF).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen document viewer with zoom and share capabilities
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final DocumentEntity document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  final TransformationController _transformationController =
      TransformationController();
  bool _showInfo = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final document = widget.document;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.tooltipClose,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.tooltipShareDocument,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white),
            ),
            onPressed: () => _shareDocument(context),
          ),
          IconButton(
            tooltip: l10n.tooltipToggleInformation,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showInfo ? Icons.info_rounded : Icons.info_outline_rounded,
                color: Colors.white,
              ),
            ),
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Document content
          GestureDetector(
            onDoubleTap: _resetZoom,
            child: document.isImage
                ? InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        File(document.localPath),
                        fit: BoxFit.contain,
                        semanticLabel: 'Document: ${document.name}',
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorState(),
                      ),
                    ),
                  )
                : _buildPdfViewer(document),
          ),

          // Info overlay
          if (_showInfo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildInfoOverlay(document, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(DocumentEntity document) {
    final l10n = AppLocalizations.of(context);
    // For PDF, we show a placeholder with option to open externally
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 80,
            color: Colors.red.shade300,
          ),
          SizedBox(height: AppSpacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              document.name,
              style: AppTypography.h3.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            document.fileSizeFormatted,
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
          SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => _openInExternalViewer(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.openInPdfViewer),
          ),
          SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => _shareDocument(context),
            icon: const Icon(Icons.share_rounded, color: Colors.white70),
            label: Text(l10n.share, style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoOverlay(DocumentEntity document, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              document.name,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: document.type.color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        document.type.icon,
                        size: 14,
                        color: document.type.color,
                      ),
                      SizedBox(width: 4),
                      Text(
                        document.type.displayName,
                        style: AppTypography.caption.copyWith(
                          color: document.type.color,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  document.fileSizeFormatted,
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  AppDateUtils.formatRelative(document.createdAt),
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
        SizedBox(height: AppSpacing.md),
        Text(
          'Unable to load document',
          style: AppTypography.body.copyWith(color: Colors.white70),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'The file may have been moved or deleted',
          style: AppTypography.caption.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  /// Opens the document in the system's default external viewer (e.g., PDF viewer)
  Future<void> _openInExternalViewer(BuildContext context) async {
    HapticFeedback.selectionClick();

    final l10n = AppLocalizations.of(context);
    final filePath = widget.document.localPath;
    final file = File(filePath);

    // Check if file exists before trying to open
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fileNotFound),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await OpenFilex.open(filePath);

    // Handle different result types
    if (context.mounted) {
      switch (result.type) {
        case ResultType.done:
          // Successfully opened - no action needed
          break;
        case ResultType.noAppToOpen:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No app found to open this file. Try sharing instead.',
              ),
            ),
          );
          break;
        case ResultType.fileNotFound:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fileNotFoundError),
              backgroundColor: Colors.red,
            ),
          );
          break;
        case ResultType.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.permissionDenied),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        case ResultType.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorOpeningFile(result.message)),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    }
  }

  Future<void> _shareDocument(BuildContext context) async {
    HapticFeedback.selectionClick();

    final l10n = AppLocalizations.of(context);
    final filePath = widget.document.localPath;
    final file = File(filePath);

    // Check if file exists before trying to share
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fileNotFound),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final xFile = XFile(filePath);
      await SharePlus.instance.share(
        ShareParams(files: [xFile], text: widget.document.name),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToShareDocument(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
