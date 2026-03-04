import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/bulk_import/data/services/csv_template_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/import_confirmation_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  bool _isLoading = false;

  Future<void> _downloadTemplate() async {
    HapticFeedback.mediumImpact();
    try {
      await CsvTemplateService.downloadTemplate();
      if (mounted) {
        AppFeedback.showSuccess(context, 'Template ready to share/save');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Failed to create template: $e');
      }
    }
  }

  Future<void> _uploadFile() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    // Suspend auto-lock during file picker to prevent locking
    // when returning from the system file picker
    ref.read(securityProvider.notifier).suspendAutoLock();

    late final PlatformFile selectedFile;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      selectedFile = result.files.first;
    } finally {
      // Resume auto-lock after file picker operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
    }

    if (selectedFile.bytes == null) {
      if (mounted) AppFeedback.showError(context, 'Could not read file');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Parse the CSV
      final parseResult = SimpleCsvParser.parse(selectedFile.bytes!);

      if (parseResult.validRows == 0) {
        if (mounted) {
          AppFeedback.showError(
            context,
            parseResult.errors.isNotEmpty
                ? parseResult.errors.first
                : 'No valid rows found in file',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Navigate to confirmation screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImportConfirmationScreen(
              parseResult: parseResult,
              fileName: selectedFile.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Error reading file: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importInvestments), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
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
                        Icons.upload_file_rounded,
                        size: 48,
                        color: isDark
                            ? AppColors.accentDark
                            : AppColors.accentLight,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Import from CSV',
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Download our template, fill in your data, and upload to import multiple investments at once.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Step 1: Download Template
              _buildStepCard(
                isDark: isDark,
                stepNumber: 1,
                title: 'Download Template',
                description: 'Get our CSV template with sample data',
                buttonLabel: l10n.downloadTemplate,
                buttonIcon: Icons.download_rounded,
                onPressed: _downloadTemplate,
              ),
              const SizedBox(height: AppSpacing.md),

              // Step 2: Fill Data
              _buildInfoCard(
                isDark: isDark,
                stepNumber: 2,
                title: 'Fill Your Data',
                description: 'Open in Excel/Sheets, add your investments',
                icon: Icons.edit_document,
              ),
              const SizedBox(height: AppSpacing.md),

              // Step 3: Upload
              _buildStepCard(
                isDark: isDark,
                stepNumber: 3,
                title: 'Upload CSV',
                description: 'Import your filled template',
                buttonLabel: l10n.uploadCsv,
                buttonIcon: Icons.upload_rounded,
                onPressed: _isLoading ? null : _uploadFile,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Type legend
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.typeValuesHeader, style: AppTypography.h4),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTypeLegend(
                        'INVEST',
                        'Money put into investment',
                        Colors.red,
                      ),
                      _buildTypeLegend(
                        'INCOME',
                        'Returns/dividends received',
                        Colors.green,
                      ),
                      _buildTypeLegend(
                        'RETURN',
                        'Withdrawal/maturity',
                        Colors.blue,
                      ),
                      _buildTypeLegend('FEE', 'Fees paid', Colors.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required bool isDark,
    required int stepNumber,
    required String title,
    required String description,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark
                      ? AppColors.accentDark
                      : AppColors.accentLight,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.h4),
                      Text(description, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(buttonIcon),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark
                  ? AppColors.accentDark.withAlpha(128)
                  : AppColors.accentLight.withAlpha(128),
              child: Text(
                '$stepNumber',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              icon,
              color: isDark ? AppColors.accentDark : AppColors.accentLight,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.h4),
                  Text(description, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeLegend(String type, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(desc, style: AppTypography.caption),
        ],
      ),
    );
  }
}
