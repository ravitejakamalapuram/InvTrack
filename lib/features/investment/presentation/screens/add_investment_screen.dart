import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/mixins/screen_animation_mixin.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Combined screen for adding and editing investments.
/// Pass [investmentToEdit] to edit an existing investment, or leave null to add a new one.
class AddInvestmentScreen extends ConsumerStatefulWidget {
  final InvestmentEntity? investmentToEdit;

  const AddInvestmentScreen({super.key, this.investmentToEdit});

  bool get isEditing => investmentToEdit != null;

  @override
  ConsumerState<AddInvestmentScreen> createState() =>
      _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen>
    with SingleTickerProviderStateMixin, SingleTickerScreenAnimationMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  late InvestmentType _selectedType;
  DateTime? _maturityDate;
  IncomeFrequency? _incomeFrequency;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if editing
    final investment = widget.investmentToEdit;
    _nameController = TextEditingController(text: investment?.name ?? '');
    _notesController = TextEditingController(text: investment?.notes ?? '');
    _selectedType = investment?.type ?? InvestmentType.p2pLending;
    _maturityDate = investment?.maturityDate;
    _incomeFrequency = investment?.incomeFrequency;
    initScreenAnimation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    _notesFocusNode.dispose();
    disposeScreenAnimation();
    super.dispose();
  }

  Future<void> _selectMaturityDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _maturityDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryLight,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              onSurface: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _maturityDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (widget.isEditing) {
        await ref
            .read(investmentNotifierProvider.notifier)
            .updateInvestment(
              id: widget.investmentToEdit!.id,
              name: name,
              type: _selectedType,
              notes: notes,
              maturityDate: _maturityDate,
              incomeFrequency: _incomeFrequency,
            );
      } else {
        await ref
            .read(investmentNotifierProvider.notifier)
            .addInvestment(
              name: name,
              type: _selectedType,
              notes: notes,
              maturityDate: _maturityDate,
              incomeFrequency: _incomeFrequency,
            );
      }

      if (mounted) {
        final message = widget.isEditing
            ? 'Investment updated successfully'
            : 'Investment created successfully';
        AppFeedback.showSuccess(context, message);
        context.pop(widget.isEditing ? true : null);
      }
    } catch (e) {
      if (mounted) {
        final message = widget.isEditing
            ? 'Failed to update investment'
            : 'Failed to create investment';
        AppFeedback.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white : AppColors.neutral700Light,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? 'Edit Investment' : 'Add Investment',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: buildAnimatedContent(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Investment Type Selector - Using grid layout for cleaner 2-column arrangement
                TypeSelector<InvestmentType>(
                  label: 'Investment Type',
                  subtitle: 'Select the category that best describes this investment',
                  values: InvestmentType.values,
                  selectedValue: _selectedType,
                  onSelected: (type) => setState(() => _selectedType = type),
                  colorBuilder: (type) => type.color,
                  iconBuilder: (type) => type.icon,
                  labelBuilder: (type) => type.displayName,
                  gridLayout: true,
                  compactMode: true,
                  spacing: 10,
                  runSpacing: 10,
                ),

                SizedBox(height: AppSpacing.sectionSpacing),

                // Name Field
                AppTextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  label: 'Investment Name',
                  hint: 'e.g. LenDenClub, Grip Invest',
                  prefixIcon: Icons.business_rounded,
                  maxLength: ValidationConstants.maxNameLength,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_notesFocusNode);
                  },
                ),

                SizedBox(height: AppSpacing.formFieldSpacing),

                // Notes Field - reduced to 2 lines for more compact form
                AppTextField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  label: 'Notes (Optional)',
                  hint: 'Add any details about this investment',
                  prefixIcon: Icons.edit_note_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  maxLength: ValidationConstants.maxNotesLength,
                ),

                SizedBox(height: AppSpacing.sectionSpacing),

                // Maturity Date (Optional)
                _buildMaturityDatePicker(isDark),

                SizedBox(height: AppSpacing.formFieldSpacing),

                // Income Frequency (Optional)
                _buildIncomeFrequencySelector(isDark),

                SizedBox(height: AppSpacing.xxl),

                // Submit Button
                GradientButton(
                  onPressed: _submit,
                  isLoading: _isLoading,
                  icon: widget.isEditing
                      ? Icons.save_rounded
                      : Icons.add_rounded,
                  label: widget.isEditing ? 'Save Changes' : 'Add Investment',
                ),

                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaturityDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maturity Date (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          label: 'Select Maturity Date',
          value: _maturityDate != null
              ? AppDateUtils.formatLong(_maturityDate!)
              : 'Not set',
          child: GestureDetector(
            onTap: () => _selectMaturityDate(context, isDark),
            child: GlassCard(
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: AppSizes.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.event_rounded,
                      color: AppColors.primaryLight,
                      size: AppSizes.iconSm,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      _maturityDate != null
                          ? AppDateUtils.formatLong(_maturityDate!)
                          : 'No maturity date set',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _maturityDate != null
                            ? (isDark ? Colors.white : AppColors.neutral900Light)
                            : (isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral500Light),
                      ),
                    ),
                  ),
                  if (_maturityDate != null)
                    IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral400Light,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _maturityDate = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral400Light,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeFrequencySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income Frequency (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How often does this investment pay income?',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFrequencyChip(null, 'None', Icons.block_rounded, isDark),
            ...IncomeFrequency.values.map(
              (freq) => _buildFrequencyChip(
                freq,
                freq.displayName,
                freq.icon,
                isDark,
                color: freq.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(
    IncomeFrequency? frequency,
    String label,
    IconData icon,
    bool isDark, {
    Color? color,
  }) {
    final isSelected = _incomeFrequency == frequency;
    final chipColor = color ?? AppColors.neutral500Light;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label income frequency',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _incomeFrequency = frequency);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            final backgroundColor = Color.lerp(
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              chipColor,
              progress,
            )!;
            final borderColor = Color.lerp(
              isDark ? AppColors.neutral700Dark : AppColors.neutral300Light,
              Colors.transparent,
              progress,
            )!;
            final iconBgColor = Color.lerp(
              chipColor.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.2),
              progress,
            )!;
            final iconColor = Color.lerp(chipColor, Colors.white, progress)!;
            final textColor = Color.lerp(
              isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
              Colors.white,
              progress,
            )!;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: progress > 0.1
                    ? [
                        BoxShadow(
                          color: chipColor.withValues(alpha: progress * 0.35),
                          blurRadius: 12 * progress,
                          offset: Offset(0, 4 * progress),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: textColor,
                      fontWeight:
                          progress > 0.5 ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
