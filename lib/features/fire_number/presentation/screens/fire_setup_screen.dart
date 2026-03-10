import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// FIRE setup wizard screen
class FireSetupScreen extends ConsumerStatefulWidget {
  const FireSetupScreen({super.key});

  @override
  ConsumerState<FireSetupScreen> createState() => _FireSetupScreenState();
}

class _FireSetupScreenState extends ConsumerState<FireSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form values
  late TextEditingController _monthlyExpensesController;
  int _currentAge = 30;
  int _targetFireAge = 45;
  FireType _selectedFireType = FireType.regular;
  double _safeWithdrawalRate = 4.0;
  double _inflationRate = 6.0;
  double _preRetirementReturn = 12.0;

  @override
  void initState() {
    super.initState();
    _monthlyExpensesController = TextEditingController(text: '50000');
  }

  @override
  void dispose() {
    _monthlyExpensesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final settings = FireSettingsEntity(
        id: const Uuid().v4(),
        monthlyExpenses:
            double.tryParse(_monthlyExpensesController.text) ?? 50000,
        currentAge: _currentAge,
        targetFireAge: _targetFireAge,
        fireType: _selectedFireType,
        safeWithdrawalRate: _safeWithdrawalRate,
        inflationRate: _inflationRate,
        preRetirementReturn: _preRetirementReturn,
        isSetupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(fireSettingsNotifierProvider.notifier)
          .saveSettings(settings);

      if (mounted) {
        context.go('/fire');
      }
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.handle(e, st, context: context, showFeedback: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('FIRE Setup', style: AppTypography.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
                tooltip: l10n.tooltipGoBack,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.safePop(),
                tooltip: l10n.tooltipCloseSetup,
              ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(isDark),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1AgeSetup(isDark, l10n),
                  _buildStep2Expenses(isDark, l10n),
                  _buildStep3FireType(isDark, l10n),
                  _buildStep4Advanced(isDark, l10n),
                ],
              ),
            ),
            // Navigation buttons
            _buildNavigationButtons(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    : (isDark
                          ? AppColors.neutral700Dark
                          : AppColors.neutral200Light),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1AgeSetup(bool isDark, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Age',
            style: AppTypography.h1.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Tell us about your current age and when you want to achieve FIRE.',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          // Current Age
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Age',
                  style: AppTypography.h4.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _currentAge > 18
                          ? () => setState(() => _currentAge--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: l10n.tooltipDecreaseAge,
                    ),
                    Text(
                      '$_currentAge',
                      style: AppTypography.displaySmall.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      onPressed: _currentAge < 70
                          ? () => setState(() => _currentAge++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: l10n.tooltipIncreaseAge,
                    ),
                  ],
                ),
                Slider(
                  value: _currentAge.toDouble(),
                  min: 18,
                  max: 70,
                  divisions: 52,
                  onChanged: (v) => setState(() => _currentAge = v.round()),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          // Target FIRE Age
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target FIRE Age',
                  style: AppTypography.h4.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _targetFireAge > _currentAge + 5
                          ? () => setState(() => _targetFireAge--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: l10n.tooltipDecreaseTargetAge,
                    ),
                    Text(
                      '$_targetFireAge',
                      style: AppTypography.displaySmall.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      onPressed: _targetFireAge < 70
                          ? () => setState(() => _targetFireAge++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: l10n.tooltipIncreaseTargetAge,
                    ),
                  ],
                ),
                Slider(
                  value: _targetFireAge.toDouble(),
                  min: (_currentAge + 5).toDouble(),
                  max: 70,
                  divisions: (70 - _currentAge - 5).clamp(1, 52),
                  onChanged: (v) => setState(() => _targetFireAge = v.round()),
                ),
                Center(
                  child: Text(
                    '${_targetFireAge - _currentAge} years from now',
                    style: AppTypography.small.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Expenses(bool isDark, AppLocalizations l10n) {
    final currencySymbol = ref.watch(currencySymbolProvider);

    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Expenses',
            style: AppTypography.h1.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'How much do you spend monthly? This helps calculate your FIRE number.',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _monthlyExpensesController,
            label: 'Monthly Expenses',
            hint: 'e.g., 50000',
            prefixText: '$currencySymbol ',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Enter a valid number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3FireType(bool isDark, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIRE Type',
            style: AppTypography.h1.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Choose your FIRE lifestyle. This affects your target number.',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          ...FireType.values.map((type) => _buildFireTypeOption(type, isDark)),
        ],
      ),
    );
  }

  Widget _buildFireTypeOption(FireType type, bool isDark) {
    final isSelected = _selectedFireType == type;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFireType = type);
        },
        backgroundColor: isSelected
            ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                  .withValues(alpha: 0.1)
            : null,
        child: Row(
          children: [
            Icon(
              type.icon,
              color: isSelected
                  ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                  : (isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  Text(
                    type.description,
                    style: AppTypography.small.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Advanced(bool isDark, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: AppTypography.h1.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Fine-tune your assumptions. These are pre-filled with recommended values.',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          _buildSliderSetting(
            isDark,
            label: 'Safe Withdrawal Rate',
            description:
                'The percentage of your portfolio you can withdraw annually. '
                '4% is the classic rule, but 3-3.5% is safer for early retirement.',
            value: _safeWithdrawalRate,
            min: 2.5,
            max: 5.0,
            suffix: '%',
            onChanged: (v) => setState(() => _safeWithdrawalRate = v),
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSliderSetting(
            isDark,
            label: 'Expected Inflation',
            description:
                'Assumed annual inflation rate. Higher inflation means '
                'you\'ll need a larger FIRE corpus. India averages 5-7%.',
            value: _inflationRate,
            min: 4.0,
            max: 10.0,
            suffix: '%',
            onChanged: (v) => setState(() => _inflationRate = v),
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSliderSetting(
            isDark,
            label: 'Pre-retirement Return',
            description:
                'Expected annual return on investments before retirement. '
                'This affects how fast your portfolio grows. 10-12% is typical for equity.',
            value: _preRetirementReturn,
            min: 8.0,
            max: 15.0,
            suffix: '%',
            onChanged: (v) => setState(() => _preRetirementReturn = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    bool isDark, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
    String? description,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}$suffix',
                style: AppTypography.h4.copyWith(
                  color: isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.sm),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: GradientButton(
        onPressed: _nextStep,
        isLoading: _isLoading,
        label: _currentStep < 3 ? 'Continue' : 'Complete Setup',
        icon: _currentStep < 3 ? Icons.arrow_forward : Icons.check,
      ),
    );
  }
}
