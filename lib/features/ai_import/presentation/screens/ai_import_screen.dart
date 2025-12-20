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

    // Listen for state changes to navigate
    ref.listen<AIImportStateData>(aiImportProvider, (previous, next) {
      if (next.state == AIImportState.reviewing && 
          previous?.state != AIImportState.reviewing) {
        // Navigate to review screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ReviewExtractedCashflowsScreen(),
          ),
        );
      } else if (next.state == AIImportState.completed) {
        AppFeedback.showSuccess(context, 'Cash flows imported successfully!');
        Navigator.of(context).pop();
      } else if (next.state == AIImportState.error && next.errorMessage != null) {
        AppFeedback.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : AppColors.neutral700Light,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'AI Document Import',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Document Parsing',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.neutral900Light,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Powered by Google Gemini AI',
                              style: AppTypography.small.copyWith(
                                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload your investment documents and let AI extract cash flow data automatically.',
                    style: AppTypography.body.copyWith(
                      color: isDark ? AppColors.neutral300Dark : AppColors.neutral600Light,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Supported formats
            _buildSupportedFormats(isDark),
            
            const Spacer(),
            
            // Status / Loading indicator
            _buildStatusIndicator(importState, isDark),
            
            const SizedBox(height: 24),
            
            // Upload button
            GradientButton(
              onPressed: importState.state == AIImportState.idle ||
                      importState.state == AIImportState.error
                  ? () {
                      HapticFeedback.lightImpact();
                      ref.read(aiImportProvider.notifier).pickDocument();
                    }
                  : null,
              isLoading: importState.state == AIImportState.pickingFile ||
                  importState.state == AIImportState.extracting ||
                  importState.state == AIImportState.uploading,
              icon: Icons.upload_file_rounded,
              label: _getButtonLabel(importState.state),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedFormats(bool isDark) {
    final formats = [
      {'icon': Icons.table_chart, 'label': 'CSV', 'color': AppColors.graphTeal},
      {'icon': Icons.grid_on, 'label': 'Excel', 'color': AppColors.graphEmerald},
      {'icon': Icons.picture_as_pdf, 'label': 'PDF', 'color': AppColors.graphRose},
      {'icon': Icons.image, 'label': 'Images', 'color': AppColors.graphAmber},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supported Formats',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: formats.map((format) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (format['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    format['icon'] as IconData,
                    color: format['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  format['label'] as String,
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(AIImportStateData state, bool isDark) {
    if (state.state == AIImportState.idle) {
      return const SizedBox.shrink();
    }

    String message;
    IconData icon;
    Color color;

    switch (state.state) {
      case AIImportState.pickingFile:
        message = 'Selecting file...';
        icon = Icons.folder_open;
        color = AppColors.primaryLight;
      case AIImportState.uploading:
        message = 'Uploading document...';
        icon = Icons.cloud_upload;
        color = AppColors.accentLight;
      case AIImportState.extracting:
        message = 'AI is analyzing your document...';
        icon = Icons.auto_awesome;
        color = AppColors.warningLight;
      case AIImportState.error:
        message = 'Error occurred';
        icon = Icons.error_outline;
        color = AppColors.dangerLight;
      default:
        return const SizedBox.shrink();
    }

    return GlassCard(
      child: Row(
        children: [
          if (state.state != AIImportState.error)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                if (state.selectedFile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.selectedFile!.name,
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonLabel(AIImportState state) {
    switch (state) {
      case AIImportState.pickingFile:
        return 'Selecting...';
      case AIImportState.uploading:
        return 'Uploading...';
      case AIImportState.extracting:
        return 'Analyzing...';
      case AIImportState.error:
        return 'Try Again';
      default:
        return 'Select Document';
    }
  }
}

