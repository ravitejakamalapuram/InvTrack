import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/investment/presentation/providers/custom_investment_type_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/custom_type_messages.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/custom_types_sheet.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The optional "Custom type" field of the investment form, shown for an
/// investment of type Other (#936).
///
/// Saved types are offered as suggestions. Saving what was typed as a
/// reusable type is an explicit action: nothing is saved while typing, and
/// the label of an investment is stored with the investment either way.
class CustomTypeField extends ConsumerWidget {
  const CustomTypeField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral500Light;
    final saved = ref.watch(customTypeSuggestionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: controller,
          label: l10n.customTypeFieldLabel,
          hint: l10n.customTypeFieldHint,
          prefixIcon: Icons.label_outline_rounded,
          textCapitalization: TextCapitalization.sentences,
          maxLength: CustomTypeLabel.maxLength,
        ),
        SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.customTypeFieldHelper,
          style: AppTypography.small.copyWith(color: mutedColor),
        ),
        if (saved.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            l10n.customTypeSavedTypesHeading,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type in saved)
                Semantics(
                  button: true,
                  label: l10n.customTypeUseSemantics(type.label),
                  excludeSemantics: true,
                  child: ActionChip(
                    label: Text(type.label),
                    onPressed: () {
                      controller.value = TextEditingValue(
                        text: type.label,
                        selection: TextSelection.collapsed(
                          offset: type.label.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _Actions(
            controller: controller,
            savedKeys: {for (final type in saved) type.key},
            mutedColor: mutedColor,
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.controller,
    required this.savedKeys,
    required this.mutedColor,
  });

  final TextEditingController controller;
  final Set<String> savedKeys;
  final Color mutedColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = CustomTypeLabel.clean(controller.text);
    final hasText = text.isNotEmpty;
    final alreadySaved =
        hasText && savedKeys.contains(CustomTypeLabel.keyOf(text));
    final atLimit = savedKeys.length >= CustomTypeLabel.maxActiveDefinitions;
    final canSave =
        hasText &&
        !alreadySaved &&
        !atLimit &&
        !CustomTypeLabel.exceedsMaxLength(text);
    final note = !hasText
        ? null
        : alreadySaved
        ? l10n.customTypeAlreadySaved
        : atLimit
        ? l10n.customTypeLimitReached(CustomTypeLabel.maxActiveDefinitions)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            TextButton(
              onPressed: canSave ? () => _save(context, ref) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_add_outlined, size: 18),
                  SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(l10n.customTypeSaveAction)),
                ],
              ),
            ),
            if (savedKeys.isNotEmpty)
              TextButton(
                onPressed: () => showCustomTypesSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(child: Text(l10n.customTypeManageAction)),
                  ],
                ),
              ),
          ],
        ),
        if (note != null)
          Text(note, style: AppTypography.small.copyWith(color: mutedColor)),
      ],
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    String? message;
    var saved = false;
    try {
      final change = await ref
          .read(customInvestmentTypeNotifierProvider.notifier)
          .save(controller.text);
      final type = change.result;
      if (change.issue != null) {
        message = customTypeIssueMessage(l10n, change.issue!);
      } else if (type != null) {
        saved = true;
        message = l10n.customTypeSaved(type.label);
      }
    } catch (_) {
      message = l10n.customTypeErrorGeneric;
    }
    if (!context.mounted || message == null) return;
    if (saved) {
      AppFeedback.showSuccess(context, message);
    } else {
      AppFeedback.showError(context, message);
    }
  }
}
