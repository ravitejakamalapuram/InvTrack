/// Export row at the bottom of the Tax-Year (FY) report (#800): PDF is the
/// primary (gradient) action, CSV the outlined one.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_export_csv_button.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_pdf_export_button.dart';

class FyReportActions extends StatelessWidget {
  const FyReportActions({super.key, required this.fyYear});

  final int fyYear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.primaryGradientDark
                : AppColors.primaryGradient,
            borderRadius: AppSizes.borderRadiusXl,
          ),
          child: FyPdfExportButton(fyYear: fyYear, style: FyExportStyle.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        FYExportCsvButton(fyYear: fyYear, style: FyExportStyle.outlined),
      ],
    );
  }
}
