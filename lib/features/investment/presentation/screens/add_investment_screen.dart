import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/mixins/screen_animation_mixin.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';

class AddInvestmentScreen extends ConsumerStatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  ConsumerState<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen>
    with SingleTickerProviderStateMixin, SingleTickerScreenAnimationMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  InvestmentType _selectedType = InvestmentType.p2pLending;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(investmentNotifierProvider.notifier).addInvestment(
        name: _nameController.text.trim(),
        type: _selectedType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        AppFeedback.showSuccess(context, 'Investment created successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Failed to create investment');
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
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
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
          'Add Investment',
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
                // Investment Type Selector
                TypeSelector<InvestmentType>(
                  label: 'Investment Type',
                  values: InvestmentType.values,
                  selectedValue: _selectedType,
                  onSelected: (type) => setState(() => _selectedType = type),
                  colorBuilder: (type) => type.color,
                  iconBuilder: (type) => type.icon,
                  labelBuilder: (type) => type.displayName,
                ),

                SizedBox(height: AppSpacing.sectionSpacing),

                // Name Field
                AppTextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  label: 'Investment Name',
                  hint: 'e.g. LenDenClub, Grip Invest',
                  prefixIcon: Icons.label_outline_rounded,
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

                // Notes Field
                AppTextField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  label: 'Notes (Optional)',
                  hint: 'e.g. Investment details, platform info',
                  prefixIcon: Icons.notes_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),

                SizedBox(height: AppSpacing.xxxl),

                // Submit Button
                GradientButton(
                  onPressed: _submit,
                  isLoading: _isLoading,
                  icon: Icons.add_rounded,
                  label: 'Add Investment',
                ),

                SizedBox(height: AppSpacing.formFieldSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
