/// Bottom sheet for editing document metadata (name and type).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Bottom sheet for editing document name and type
class EditDocumentSheet extends ConsumerStatefulWidget {
  final DocumentEntity document;

  const EditDocumentSheet({super.key, required this.document});

  @override
  ConsumerState<EditDocumentSheet> createState() => _EditDocumentSheetState();
}

class _EditDocumentSheetState extends ConsumerState<EditDocumentSheet> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  late DocumentType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.document.name);
    _selectedType = widget.document.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              'Edit Document',
              style: AppTypography.h2.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Document Name',
                hintText: 'e.g., Purchase Receipt',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveChanges,
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
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final hasNameChanged = newName != widget.document.name;
    final hasTypeChanged = _selectedType != widget.document.type;

    if (!hasNameChanged && !hasTypeChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();

    try {
      await ref
          .read(documentNotifierProvider)
          .updateDocument(
            documentId: widget.document.id,
            name: hasNameChanged ? newName : null,
            type: hasTypeChanged ? _selectedType : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.showSuccess(context, 'Document updated');
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
