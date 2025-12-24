import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

class EditInvestmentScreen extends ConsumerStatefulWidget {
  final InvestmentEntity investment;

  const EditInvestmentScreen({super.key, required this.investment});

  @override
  ConsumerState<EditInvestmentScreen> createState() => _EditInvestmentScreenState();
}

class _EditInvestmentScreenState extends ConsumerState<EditInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late InvestmentType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.investment.name);
    _notesController = TextEditingController(text: widget.investment.notes ?? '');
    _selectedType = widget.investment.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(investmentNotifierProvider.notifier).updateInvestment(
        id: widget.investment.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        AppFeedback.showSuccess(context, 'Investment updated successfully');
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Failed to update investment');
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
          'Edit Investment',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Name Field
          AppTextField(
            controller: _nameController,
            label: 'Investment Name',
            hint: 'e.g., P2P Lending - LendingClub',
            prefixIcon: Icons.label_outline_rounded,
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),

          SizedBox(height: AppSpacing.formFieldSpacing),

          // Notes Field
          AppTextField(
            controller: _notesController,
            label: 'Notes (Optional)',
            hint: 'Add any notes about this investment...',
            prefixIcon: Icons.notes_rounded,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
          ),

          SizedBox(height: AppSpacing.sectionSpacing),

          // Type Selector
          TypeSelector<InvestmentType>(
            label: 'Investment Type',
            values: InvestmentType.values,
            selectedValue: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
            colorBuilder: (type) => type.color,
            iconBuilder: (type) => type.icon,
            labelBuilder: (type) => type.displayName,
          ),

          SizedBox(height: AppSpacing.xxl),

          // Submit Button
          GradientButton(
            onPressed: _submit,
            isLoading: _isLoading,
            icon: Icons.save_rounded,
            label: 'Save Changes',
          ),
        ],
      ),
    );
  }
}
