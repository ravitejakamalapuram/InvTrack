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
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

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

            // Source selection buttons
            if (_selectedBytes == null) ...[
              _buildSourceButtons(isDark),
            ] else ...[
              // Preview and form
              _buildPreviewAndForm(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButtons(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SourceButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: _pickFromCamera,
                isDark: isDark,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SourceButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: _pickFromGallery,
                isDark: isDark,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        _SourceButton(
          icon: Icons.insert_drive_file_rounded,
          label: 'Choose PDF File',
          onTap: _pickPdfFile,
          isDark: isDark,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildPreviewAndForm(bool isDark) {
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
                child: const Text('Change File'),
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
                    : const Text('Save'),
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
        AppFeedback.showError(context, 'Could not access camera');
      }
    } finally {
      // Resume auto-lock after camera operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();

    // Check and request photos permission
    final result = await _permissionService.requestPhotos();
    if (!mounted) return;

    if (!_handlePermissionResult(result, 'photo library')) {
      return;
    }

    // Suspend auto-lock during gallery picker to prevent locking
    // when returning from the photo picker
    ref.read(securityProvider.notifier).suspendAutoLock();

    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
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
        AppFeedback.showError(context, 'Could not access photo library');
      }
    } finally {
      // Resume auto-lock after gallery operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
    }
  }

  Future<void> _pickPdfFile() async {
    HapticFeedback.selectionClick();

    // Suspend auto-lock during file picker to prevent locking
    // when returning from the system file picker
    ref.read(securityProvider.notifier).suspendAutoLock();

    // FilePicker uses SAF on Android, no explicit permission needed
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null && mounted) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedBytes = bytes;
          _selectedFileName = result.files.single.name;
          _nameController.text = _suggestName(result.files.single.name);
        });
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Could not access file');
      }
    } finally {
      // Resume auto-lock after file picker operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          'InvTracker needs $permissionName access to attach documents. '
          'Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openSettings();
            },
            child: const Text('Open Settings'),
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
  final VoidCallback onTap;
  final bool isDark;
  final bool fullWidth;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.fullWidth = false,
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
            ),
          ),
        ],
      ),
    );
  }
}
