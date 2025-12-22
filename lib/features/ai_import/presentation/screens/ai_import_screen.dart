import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/ai_import/domain/services/ai_document_parsing_service.dart';
import 'package:inv_tracker/features/ai_import/presentation/providers/ai_import_provider.dart';
import 'package:inv_tracker/features/ai_import/presentation/screens/review_extracted_cashflows_screen.dart';

class AIImportScreen extends ConsumerStatefulWidget {
  const AIImportScreen({super.key});

  @override
  ConsumerState<AIImportScreen> createState() => _AIImportScreenState();
}

class _AIImportScreenState extends ConsumerState<AIImportScreen> {
  @override
  void initState() {
    super.initState();
    // Reset state when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiImportProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importState = ref.watch(aiImportProvider);

    // Listen for state changes and navigate to review screen
    ref.listen<AIImportStateData>(aiImportProvider, (previous, next) {
      if (next.state == AIImportState.reviewing && next.extractionResult != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ReviewExtractedCashflowsScreen(),
          ),
        );
      } else if (next.state == AIImportState.error && next.errorMessage != null) {
        AppFeedback.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Powered Import'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 48,
                        color: isDark ? AppColors.accentDark : AppColors.accentLight,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Smart Document Import',
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Upload your investment documents and let AI extract the cash flow data automatically.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Supported formats
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Supported Formats', style: AppTypography.h4),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: AIDocumentParsingService.supportedExtensions
                            .map((ext) => Chip(
                                  label: Text(
                                    ext.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: isDark
                                      ? AppColors.accentDark.withAlpha(40)
                                      : AppColors.accentLight.withAlpha(30),
                                  side: BorderSide(
                                    color: isDark
                                        ? AppColors.accentDark.withAlpha(80)
                                        : AppColors.accentLight.withAlpha(60),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Max file size: 10MB',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Status indicator
              if (importState.state == AIImportState.extracting) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Analyzing document with AI...',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Upload button
              GradientButton(
                onPressed: importState.state == AIImportState.extracting
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        ref.read(aiImportProvider.notifier).pickDocument();
                      },
                isLoading: importState.state == AIImportState.pickingFile ||
                    importState.state == AIImportState.extracting,
                icon: Icons.upload_file_rounded,
                label: 'Select Document',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

