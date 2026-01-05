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
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String investmentId;
  final CashFlowEntity? cashFlowToEdit;

  const AddTransactionScreen({
    super.key,
    required this.investmentId,
    this.cashFlowToEdit,
  });

  bool get isEditing => cashFlowToEdit != null;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with SingleTickerProviderStateMixin, SingleTickerScreenAnimationMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  CashFlowType _selectedType = CashFlowType.invest;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill if editing
    if (widget.cashFlowToEdit != null) {
      final cf = widget.cashFlowToEdit!;
      _amountController.text = cf.amount.toStringAsFixed(2);
      _notesController.text = cf.notes ?? '';
      _selectedDate = cf.date;
      _selectedType = cf.type;
    }

    initScreenAnimation();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    disposeScreenAnimation();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (widget.isEditing) {
        // Update existing cash flow
        await ref
            .read(investmentNotifierProvider.notifier)
            .updateCashFlow(
              id: widget.cashFlowToEdit!.id,
              investmentId: widget.investmentId,
              type: _selectedType,
              date: _selectedDate,
              amount: amount,
              notes: notes,
              createdAt: widget.cashFlowToEdit!.createdAt,
            );
      } else {
        // Add new cash flow
        await ref
            .read(investmentNotifierProvider.notifier)
            .addCashFlow(
              investmentId: widget.investmentId,
              type: _selectedType,
              date: _selectedDate,
              amount: amount,
              notes: notes,
            );
      }

      if (mounted) {
        final message = widget.isEditing
            ? 'Transaction updated successfully'
            : 'Transaction added successfully';
        AppFeedback.showSuccess(context, message);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final message = widget.isEditing
            ? 'Failed to update transaction'
            : 'Failed to add transaction';
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
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyFormat = ref.watch(currencyFormatPreciseProvider);

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
          widget.isEditing ? 'Edit Cash Flow' : 'Add Cash Flow',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: buildAnimatedContent(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Cash Flow Type Selector - Using grid layout for better UX
              TypeSelector<CashFlowType>(
                label: 'Cash Flow Type',
                subtitle: 'Select the type of cash movement',
                values: CashFlowType.values,
                selectedValue: _selectedType,
                onSelected: (type) => setState(() => _selectedType = type),
                colorBuilder: (type) => type.color,
                iconBuilder: (type) => type.iconData,
                labelBuilder: (type) => type.displayName,
                gridLayout: true,
                compactMode: true,
                spacing: 10,
                runSpacing: 10,
              ),

              SizedBox(height: AppSpacing.sectionSpacing),

              // Date Picker
              Text(
                'Date',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: () => _selectDate(context, isDark),
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
                          Icons.calendar_today_rounded,
                          color: AppColors.primaryLight,
                          size: AppSizes.iconSm,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm + 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppDateUtils.formatDayOfWeek(_selectedDate),
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light,
                              ),
                            ),
                            Text(
                              AppDateUtils.formatLong(_selectedDate),
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.neutral900Light,
                              ),
                            ),
                          ],
                        ),
                      ),
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

              SizedBox(height: AppSpacing.sectionSpacing),

              // Amount Field
              _buildNumberField(
                controller: _amountController,
                label: 'Amount',
                hint: '0.00',
                icon: Icons.attach_money_rounded,
                isDark: isDark,
                prefix: currencySymbol,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Invalid amount';
                  if (parsed <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),

              SizedBox(height: AppSpacing.formFieldSpacing),

              // Notes Field - reduced to 2 lines for compact form
              AppTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Add any notes about this transaction...',
                prefixIcon: Icons.edit_note_rounded,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                maxLength: ValidationConstants.maxTransactionNotesLength,
              ),

              SizedBox(height: AppSpacing.sectionSpacing),

              // Amount Preview
              GlassCard(
                padding: AppSpacing.cardPaddingLarge,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedType.isOutflow ? 'Cash Out' : 'Cash In',
                          style: AppTypography.body.copyWith(
                            color: isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral500Light,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        ListenableBuilder(
                          listenable: _amountController,
                          builder: (context, _) {
                            final amount =
                                double.tryParse(_amountController.text) ?? 0;
                            return Text(
                              currencyFormat.format(amount),
                              style: AppTypography.numberLarge.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.neutral900Light,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: _selectedType.isOutflow
                            ? AppColors.dangerGradient
                            : AppColors.successGradient,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMd + 2,
                        ),
                      ),
                      child: Icon(
                        _selectedType.isOutflow
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xxl),

              // Submit Button
              GradientButton(
                onPressed: _submit,
                isLoading: _isLoading,
                icon: _selectedType.iconData,
                label: widget.isEditing
                    ? 'Update ${_selectedType.displayName}'
                    : 'Add ${_selectedType.displayName}',
                color: _selectedType.color,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.body.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral400Light,
            ),
            prefixText: prefix,
            prefixStyle: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
