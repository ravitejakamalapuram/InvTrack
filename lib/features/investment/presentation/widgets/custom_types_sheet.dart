import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/custom_investment_type_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/custom_type_messages.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Opens the sheet that lists the saved custom types, to rename or remove
/// them (#936).
Future<void> showCustomTypesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CustomTypesSheet(),
  );
}

/// The saved custom types, each with rename and remove. Both change that one
/// saved type only: investments that use it keep their own label, so nothing
/// is reclassified or deleted.
class CustomTypesSheet extends ConsumerWidget {
  const CustomTypesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = ref.watch(customTypeSuggestionsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.customTypeManageTitle, style: AppTypography.h4),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              l10n.customTypeManageNote,
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            if (saved.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(l10n.customTypeManageEmpty),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final type in saved)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(type.label),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.customTypeRenameTooltip(type.label),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _rename(context, type),
                            ),
                            IconButton(
                              tooltip: l10n.customTypeRemoveTooltip(type.label),
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _remove(context, ref, type),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, CustomInvestmentType type) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RenameDialog(type: type),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CustomInvestmentType type,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: l10n.customTypeRemoveTitle,
      message: l10n.customTypeRemoveMessage(type.label),
      confirmText: l10n.customTypeRemoveConfirm,
      cancelText: l10n.cancel,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(customInvestmentTypeNotifierProvider.notifier)
          .remove(type.id);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showError(context, l10n.customTypeErrorGeneric);
      }
    }
  }
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.type});

  final CustomInvestmentType type;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.type.label);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final change = await ref
          .read(customInvestmentTypeNotifierProvider.notifier)
          .rename(widget.type.id, _controller.text);
      if (!mounted) return;
      if (change.issue != null) {
        setState(() {
          _saving = false;
          _error = customTypeIssueMessage(l10n, change.issue!);
        });
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.customTypeErrorGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.customTypeRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: CustomTypeLabel.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.customTypeNameLabel,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: Text(l10n.customTypeRenameConfirm),
        ),
      ],
    );
  }
}
