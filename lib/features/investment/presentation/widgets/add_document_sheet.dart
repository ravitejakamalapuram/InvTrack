/// Bottom sheet for adding a new document to an investment.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inv_tracker/core/services/permission_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Bottom sheet for adding documents via camera, gallery, or file picker
class AddDocumentSheet extends ConsumerStatefulWidget {
  final String investmentId;

  const AddDocumentSheet({super.key, required this.investmentId});

  @override
  ConsumerState<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends ConsumerState<AddDocumentSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DocumentType _selectedType = DocumentType.receipt;
  Uint8List? _selectedBytes;
  String? _selectedFileName;
  bool _isLoading = false;

  // Multi-file selection state
  List<_SelectedFile> _multipleFiles = [];
  bool _isMultiMode = false;

  // Loading state for file reading (separate from save loading)
  bool _isReadingFiles = false;

  // Upload progress tracking
  int _uploadedCount = 0;
  int _totalToUpload = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + bottomPadding,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Add Document',
              style: AppTypography.h2.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // Source selection buttons or loading or content
            if (_isReadingFiles) ...[
              // Loading state while reading files
              _buildFileReadingLoader(isDark),
            ] else if (_selectedBytes == null && _multipleFiles.isEmpty) ...[
              _buildSourceButtons(isDark),
            ] else if (_isMultiMode && _multipleFiles.isNotEmpty) ...[
              // Multi-file mode
              _buildMultiFileForm(isDark),
            ] else ...[
              // Single file preview and form
              _buildPreviewAndForm(isDark),
            ],
          ],
        ),
      ),
    );
  }

  /// Loading indicator while reading selected files
  Widget _buildFileReadingLoader(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Reading files...',
            style: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'This may take a moment for large files',
            style: AppTypography.caption.copyWith(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButtons(bool isDark) {
    return Row(
      children: [
        // Camera button - for quick capture
        Expanded(
          child: _SourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            subtitle: 'Take a photo',
            onTap: _pickFromCamera,
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        // Select Files button - for any file type, any number
        Expanded(
          child: _SourceButton(
            icon: Icons.folder_open_rounded,
            label: 'Select Files',
            subtitle: 'PDFs, images, etc.',
            onTap: _pickFiles,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewAndForm(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final isImage =
        _selectedFileName != null &&
        DocumentMimeTypes.isImage(_selectedFileName!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_selectedBytes!, fit: BoxFit.cover),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 48,
                        color: Colors.red,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        _selectedFileName ?? 'PDF',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
        ),
        SizedBox(height: AppSpacing.md),

        // Name field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g., Purchase Receipt',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a name';
            }
            if (value.length > 100) {
              return 'Name cannot exceed 100 characters';
            }
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),

        // Type selector
        TypeSelector<DocumentType>(
          label: 'Document Type',
          subtitle: 'Categorize this document',
          values: DocumentType.values,
          selectedValue: _selectedType,
          onSelected: (type) => setState(() => _selectedType = type),
          labelBuilder: (type) => type.displayName,
          iconBuilder: (type) => type.icon,
          colorBuilder: (type) => type.color,
          gridLayout: true,
          compactMode: true,
        ),
        SizedBox(height: AppSpacing.lg),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedBytes = null;
                    _selectedFileName = null;
                    _nameController.clear();
                  });
                },
                child: Text(l10n.changeFile),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _saveDocument,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _permissionService = PermissionService();

  Future<void> _pickFromCamera() async {
    HapticFeedback.selectionClick();

    // Check and request camera permission
    final result = await _permissionService.requestCamera();
    if (!mounted) return;

    if (!_handlePermissionResult(result, 'camera')) {
      return;
    }

    // Suspend auto-lock during camera operation to prevent locking
    // when returning from the camera app
    ref.read(securityProvider.notifier).suspendAutoLock();

    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedBytes = bytes;
          _selectedFileName = image.name;
          _nameController.text = _suggestName(image.name);
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppFeedback.showError(context, l10n.couldNotAccessCamera);
      }
    } finally {
      // Resume auto-lock after camera operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
    }
  }

  /// Unified file picker - supports all file types and multiple selection
  Future<void> _pickFiles() async {
    HapticFeedback.selectionClick();

    // Suspend auto-lock during file picker
    ref.read(securityProvider.notifier).suspendAutoLock();

    // Get last opened directory for better UX
    final lastDirectory = ref.read(lastFilePickerDirectoryProvider);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'],
        allowMultiple: true,
        initialDirectory: lastDirectory,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        // Show loading indicator while reading files
        setState(() => _isReadingFiles = true);

        final files = <_SelectedFile>[];
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            final file = File(platformFile.path!);
            final bytes = await file.readAsBytes();
            final detectedType = _detectDocumentType(platformFile.name);
            files.add(
              _SelectedFile(
                bytes: bytes,
                fileName: platformFile.name,
                suggestedName: _suggestName(platformFile.name),
                autoDetectedType: detectedType,
                selectedType: detectedType, // Initially same as auto-detected
              ),
            );
          }
        }

        if (mounted) {
          setState(() => _isReadingFiles = false);

          if (files.isNotEmpty) {
            // Save the directory from the first file for next time
            saveLastFilePickerDirectory(ref, result.files.first.path);

            // If single file, use single file mode for simpler UX
            if (files.length == 1) {
              setState(() {
                _selectedBytes = files.first.bytes;
                _selectedFileName = files.first.fileName;
                _nameController.text = files.first.suggestedName;
                _selectedType = files.first.selectedType;
              });
            } else {
              setState(() {
                _multipleFiles = files;
                _isMultiMode = true;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReadingFiles = false);
        final l10n = AppLocalizations.of(context);
        AppFeedback.showError(context, l10n.couldNotAccessFiles);
      }
    } finally {
      ref.read(securityProvider.notifier).resumeAutoLock();
    }
  }

  /// Auto-detect document type from file extension
  DocumentType _detectDocumentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (DocumentMimeTypes.imageExtensions.contains(extension)) {
      return DocumentType.image;
    }
    // Default to receipt for PDFs (most common use case)
    return DocumentType.receipt;
  }

  Widget _buildMultiFileForm(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary header
        Row(
          children: [
            Icon(
              Icons.file_copy_rounded,
              color: AppColors.primaryLight,
              size: 20,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              '${_multipleFiles.length} files selected',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),

        // Files list with thumbnails
        Container(
          constraints: BoxConstraints(maxHeight: 250),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _multipleFiles.length,
            separatorBuilder: (_, _) => SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final file = _multipleFiles[index];
              final isImage = DocumentMimeTypes.isImage(file.fileName);
              return Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Thumbnail preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isImage
                          ? Image.memory(
                              file.bytes,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Document preview: ${file.fileName}',
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.red.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    // File info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.suggestedName,
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.neutral900Light,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              // Tappable type chip for per-file type selection
                              Semantics(
                                button: true,
                                label:
                                    'Change document type: ${file.selectedType.displayName}',
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => _showTypePickerForFile(
                                          index,
                                          isDark,
                                        ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: file.selectedType.color.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: file.selectedType.color
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          file.selectedType.displayName,
                                          style: AppTypography.caption.copyWith(
                                            color: file.selectedType.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 14,
                                          color: file.selectedType.color,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                _formatFileSize(file.bytes.length),
                                style: AppTypography.caption.copyWith(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Remove button
                    if (!_isLoading)
                      IconButton(
                        icon: Icon(Icons.close, size: 20),
                        tooltip: 'Remove file',
                        onPressed: () {
                          setState(() {
                            _multipleFiles.removeAt(index);
                            if (_multipleFiles.isEmpty) {
                              _isMultiMode = false;
                            }
                          });
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // Upload progress (shown during upload)
        if (_isLoading && _totalToUpload > 0) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploading...',
                    style: AppTypography.body.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                  Text(
                    '$_uploadedCount / $_totalToUpload',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: _totalToUpload > 0 ? _uploadedCount / _totalToUpload : 0,
                backgroundColor: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryLight,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _multipleFiles.clear();
                          _isMultiMode = false;
                        });
                      },
                child: Text(l10n.cancel),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _saveMultipleDocuments,
                child: _isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(l10n.saving),
                        ],
                      )
                    : Text(l10n.saveMultipleFiles(_multipleFiles.length)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Show type picker bottom sheet for a specific file
  void _showTypePickerForFile(int fileIndex, bool isDark) {
    HapticFeedback.selectionClick();
    final file = _multipleFiles[fileIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Select Type',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              file.suggestedName,
              style: AppTypography.caption.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.5,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppSpacing.lg),

            // Type options grid
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: DocumentType.values.map((type) {
                final isSelected = file.selectedType == type;
                void onTap() {
                  setState(() {
                    _multipleFiles[fileIndex].selectedType = type;
                  });
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                }

                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: type.displayName,
                  excludeSemantics: true,
                  onTap: onTap,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? type.color.withValues(alpha: 0.15)
                            : (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.05,
                              ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? type.color
                              : (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.icon,
                            size: 18,
                            color: isSelected
                                ? type.color
                                : (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.6),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            type.displayName,
                            style: AppTypography.body.copyWith(
                              color: isSelected
                                  ? type.color
                                  : (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.8),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(
              height: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMultipleDocuments() async {
    if (_multipleFiles.isEmpty) return;

    setState(() {
      _isLoading = true;
      _uploadedCount = 0;
      _totalToUpload = _multipleFiles.length;
    });

    try {
      int successCount = 0;
      for (final file in _multipleFiles) {
        await ref
            .read(documentNotifierProvider)
            .addDocument(
              investmentId: widget.investmentId,
              name: file.suggestedName,
              fileName: file.fileName,
              type: file
                  .selectedType, // Use user-selected type (or auto-detected)
              bytes: file.bytes,
            );
        successCount++;
        if (mounted) {
          setState(() => _uploadedCount = successCount);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        final l10n = AppLocalizations.of(context);
        AppFeedback.showSuccess(context, l10n.documentsAdded(successCount));
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadedCount = 0;
          _totalToUpload = 0;
        });
      }
    }
  }

  /// Handles permission result and shows appropriate UI feedback
  /// Returns true if permission was granted, false otherwise
  bool _handlePermissionResult(PermissionResult result, String permissionName) {
    switch (result) {
      case PermissionResult.granted:
      case PermissionResult.limited:
        return true;

      case PermissionResult.denied:
        AppFeedback.showError(
          context,
          'Permission denied. Please allow $permissionName access.',
        );
        return false;

      case PermissionResult.permanentlyDenied:
        _showSettingsDialog(permissionName);
        return false;

      case PermissionResult.restricted:
        AppFeedback.showError(
          context,
          'Access to $permissionName is restricted on this device.',
        );
        return false;
    }
  }

  /// Shows dialog prompting user to open settings when permission is permanently denied
  void _showSettingsDialog(String permissionName) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.permissionRequired),
        content: Text(
          'InvTracker needs $permissionName access to attach documents. '
          'Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openSettings();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  String _suggestName(String fileName) {
    // Remove extension and clean up
    final name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return name.replaceAll(RegExp(r'[_-]'), ' ').trim();
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBytes == null || _selectedFileName == null) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(documentNotifierProvider)
          .addDocument(
            investmentId: widget.investmentId,
            name: _nameController.text.trim(),
            fileName: _selectedFileName!,
            type: _selectedType,
            bytes: _selectedBytes!,
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.showSuccess(context, 'Document added');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Button for selecting document source
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _SourceButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.primaryLight),
          SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.5,
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

/// Represents a selected file for multi-file upload with auto-detected type
class _SelectedFile {
  final Uint8List bytes;
  final String fileName;
  final String suggestedName;
  final DocumentType autoDetectedType;
  DocumentType selectedType; // User can change this per-file

  _SelectedFile({
    required this.bytes,
    required this.fileName,
    required this.suggestedName,
    required this.autoDetectedType,
    DocumentType? selectedType,
  }) : selectedType = selectedType ?? autoDetectedType;
}
