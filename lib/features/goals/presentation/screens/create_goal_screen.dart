import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_icon_picker.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/investment_selector_sheet.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Screen for creating a new goal
class CreateGoalScreen extends ConsumerStatefulWidget {
  final GoalEntity? goalToEdit;

  const CreateGoalScreen({super.key, this.goalToEdit});

  bool get isEditing => goalToEdit != null;

  @override
  ConsumerState<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends ConsumerState<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late TextEditingController _monthlyIncomeController;

  late GoalType _selectedType;
  late GoalTrackingMode _trackingMode;
  DateTime? _targetDate;
  String _selectedIcon = GoalIcons.defaultIcon;
  Color _selectedColor = GoalColors.defaultColor;
  List<String> _linkedInvestmentIds = [];
  List<InvestmentType> _linkedTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goalToEdit;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetAmountController = TextEditingController(
      text: goal?.targetAmount.toStringAsFixed(0) ?? '',
    );
    _monthlyIncomeController = TextEditingController(
      text: goal?.targetMonthlyIncome?.toStringAsFixed(0) ?? '',
    );
    _selectedType = goal?.type ?? GoalType.targetAmount;
    _trackingMode = goal?.trackingMode ?? GoalTrackingMode.all;
    _targetDate = goal?.targetDate;
    _selectedIcon = goal?.icon ?? GoalIcons.defaultIcon;
    _selectedColor = goal?.color ?? GoalColors.defaultColor;
    _linkedInvestmentIds = goal?.linkedInvestmentIds ?? [];
    _linkedTypes = goal?.linkedTypes ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _monthlyIncomeController.dispose();
    super.dispose();
  }

  Future<void> _selectTargetDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final name = _nameController.text.trim();
      final targetAmount = double.tryParse(_targetAmountController.text) ?? 0;
      final monthlyIncome = _monthlyIncomeController.text.isNotEmpty
          ? double.tryParse(_monthlyIncomeController.text)
          : null;

      if (widget.isEditing) {
        await ref
            .read(goalsNotifierProvider.notifier)
            .updateGoal(
              widget.goalToEdit!.copyWith(
                name: name,
                type: _selectedType,
                targetAmount: targetAmount,
                targetMonthlyIncome: monthlyIncome,
                targetDate: _targetDate,
                trackingMode: _trackingMode,
                linkedInvestmentIds: _linkedInvestmentIds,
                linkedTypes: _linkedTypes,
                icon: _selectedIcon,
                colorValue: _selectedColor.toARGB32(),
              ),
            );
      } else {
        await ref
            .read(goalsNotifierProvider.notifier)
            .createGoal(
              name: name,
              type: _selectedType,
              targetAmount: targetAmount,
              targetMonthlyIncome: monthlyIncome,
              targetDate: _targetDate,
              trackingMode: _trackingMode,
              linkedInvestmentIds: _linkedInvestmentIds,
              linkedTypes: _linkedTypes,
              icon: _selectedIcon,
              colorValue: _selectedColor.toARGB32(),
            );
      }

      if (mounted) {
        final message = widget.isEditing ? 'Goal updated' : 'Goal created';
        AppFeedback.showSuccess(context, message);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Failed to save goal');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: _buildAppBar(isDark),
      body: _buildBody(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      title: Text(
        widget.isEditing ? 'Edit Goal' : 'Create Goal',
        style: AppTypography.h3.copyWith(
          color: isDark ? Colors.white : AppColors.neutral900Light,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon and Color picker
            _buildIconSection(isDark),
            SizedBox(height: AppSpacing.lg),

            // Goal Name
            AppTextField(
              controller: _nameController,
              label: 'Goal Name',
              hint: 'e.g., Home Down Payment',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: AppSpacing.md),

            // Goal Type
            _buildGoalTypeSelector(isDark),
            SizedBox(height: AppSpacing.md),

            // Target Amount
            AppTextField(
              controller: _targetAmountController,
              label: 'Target Amount',
              hint: 'Enter target amount',
              prefixText: currencySymbol,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            SizedBox(height: AppSpacing.md),

            // Target Monthly Income (for passive income goals)
            if (_selectedType == GoalType.incomeTarget) ...[
              AppTextField(
                controller: _monthlyIncomeController,
                label: 'Target Monthly Income',
                hint: 'Enter monthly income target',
                prefixText: currencySymbol,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: AppSpacing.md),
            ],

            // Target Date
            _buildDateSelector(isDark),
            SizedBox(height: AppSpacing.md),

            // Tracking Mode
            _buildTrackingModeSelector(isDark),
            SizedBox(height: AppSpacing.md),

            // Investment Linking (if not tracking all)
            if (_trackingMode != GoalTrackingMode.all)
              _buildInvestmentLinkingSection(isDark),

            SizedBox(height: AppSpacing.xl),

            // Submit Button
            GradientButton(
              label: widget.isEditing ? 'Save Changes' : 'Create Goal',
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
            ),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection(bool isDark) {
    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showIconPicker(context),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _selectedColor,
                    _selectedColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _selectedIcon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap to customize',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Choose icon and color',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalIconPicker(
        selectedIcon: _selectedIcon,
        selectedColor: _selectedColor,
        onIconSelected: (icon) => setState(() => _selectedIcon = icon),
        onColorSelected: (color) => setState(() => _selectedColor = color),
      ),
    );
  }

  Widget _buildGoalTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal Type',
          style: AppTypography.small.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: GoalType.values.map((type) {
            final isSelected = type == _selectedType;
            return ChoiceChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedType = type),
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
              labelStyle: AppTypography.small.copyWith(
                color: isSelected
                    ? AppColors.primaryLight
                    : (isDark ? Colors.white : AppColors.neutral900Light),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector(bool isDark) {
    return GlassCard(
      onTap: () => _selectTargetDate(context, isDark),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Date (Optional)',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _targetDate != null
                      ? AppDateUtils.formatShort(_targetDate!)
                      : 'No deadline set',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_targetDate != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() => _targetDate = null),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingModeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tracking Mode',
          style: AppTypography.small.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        RadioGroup<GoalTrackingMode>(
          groupValue: _trackingMode,
          onChanged: (v) {
            if (v != null) setState(() => _trackingMode = v);
          },
          child: Column(
            children: GoalTrackingMode.values.map((mode) {
              return RadioListTile<GoalTrackingMode>(
                value: mode,
                title: Text(mode.displayName),
                subtitle: Text(mode.description, style: AppTypography.small),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentLinkingSection(bool isDark) {
    final linkedCount = _trackingMode == GoalTrackingMode.selected
        ? _linkedInvestmentIds.length
        : _linkedTypes.length;

    return GlassCard(
      onTap: () => _showInvestmentSelector(context),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: AppColors.primaryLight),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trackingMode == GoalTrackingMode.selected
                      ? 'Link Investments'
                      : 'Link Investment Types',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  linkedCount > 0 ? '$linkedCount selected' : 'Tap to select',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  void _showInvestmentSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvestmentSelectorSheet(
        trackingMode: _trackingMode,
        selectedInvestmentIds: _linkedInvestmentIds,
        selectedTypes: _linkedTypes,
        onInvestmentsSelected: (ids) =>
            setState(() => _linkedInvestmentIds = ids),
        onTypesSelected: (types) => setState(() => _linkedTypes = types),
      ),
    );
  }
}
