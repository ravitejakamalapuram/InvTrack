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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final document = widget.document;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white),
            ),
            onPressed: _shareDocument,
          ),
          IconButton(
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
          Text(
            document.name,
            style: AppTypography.h3.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            document.fileSizeFormatted,
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
          SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _shareDocument,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open in PDF Viewer'),
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

  Future<void> _shareDocument() async {
    HapticFeedback.selectionClick();
    final file = XFile(widget.document.localPath);
    await SharePlus.instance.share(
      ShareParams(files: [file], text: widget.document.name),
    );
  }
}
