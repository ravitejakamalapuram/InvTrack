import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/sticky_form_action.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

/// The layout of the add investment form behind the first investment flow
/// (A40, #783): an app bar, the form scrolling under it, and the submit button
/// pinned at the foot ([StickyFormAction]), above the keyboard when it is open.
///
/// It lays out slots and owns no state: the screen builds the fields and keeps
/// their controllers, so the layout can be tested at any size, theme, text
/// scale and keyboard height without the screen's providers. Top to bottom:
/// the type label, the type chips (full width, so the next chip peeks at the
/// edge), then, 24px in from the edges with a form gap between them, the
/// optional [customType] field, the [name], the [amount], the [startDate] and
/// the [moreDetails] tile.
class FirstInvestmentFormView extends StatelessWidget {
  const FirstInvestmentFormView({
    super.key,
    required this.formKey,
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.typeLabel,
    required this.typeRow,
    this.customType,
    required this.name,
    required this.amount,
    required this.startDate,
    required this.moreDetails,
    required this.submitLabel,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String closeTooltip;
  final VoidCallback onClose;
  final String typeLabel;
  final Widget typeRow;
  final Widget? customType;
  final Widget name;
  final Widget amount;
  final Widget startDate;
  final Widget moreDetails;
  final String submitLabel;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gap = SizedBox(height: AppSpacing.formFieldSpacing);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: closeTooltip,
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
          onPressed: onClose,
        ),
        title: Text(
          title,
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingHorizontal,
                ),
                child: Text(
                  typeLabel,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
              ),
              typeRow,
              // The row keeps 8px above and below its chips for their glow.
              SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingHorizontal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (customType != null) ...[customType!, gap],
                    name,
                    gap,
                    amount,
                    gap,
                    startDate,
                    gap,
                    moreDetails,
                    SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // The bottom bar of the Scaffold: a floating SnackBar (the error after a
      // failed save) appears above it, not over the button. It rides above the
      // keyboard by padding itself.
      bottomNavigationBar: StickyFormAction(
        child: GradientButton(
          key: AddInvestmentKeys.submit,
          onPressed: onSubmit,
          isLoading: isLoading,
          icon: Icons.add_rounded,
          label: submitLabel,
        ),
      ),
    );
  }
}
