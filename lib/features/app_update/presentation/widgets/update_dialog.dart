import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';
import 'package:inv_tracker/features/app_update/presentation/providers/version_check_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog to show when an app update is available
class UpdateDialog extends ConsumerWidget {
  final AppVersionEntity versionInfo;
  final bool forceUpdate;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    this.forceUpdate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppSizes.borderRadiusLg,
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: AppSizes.borderRadiusMd,
              ),
              child: Icon(
                Icons.system_update,
                color: AppColors.primaryLight,
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                forceUpdate ? 'Update Required' : 'Update Available',
                style: AppTypography.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              versionInfo.updateMessage ??
                  'A new version of InvTrack is available!',
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral300Dark
                    : AppColors.neutral700Light,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral800Dark
                    : AppColors.neutral100Light,
                borderRadius: AppSizes.borderRadiusMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Latest Version:',
                    style: AppTypography.small.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral600Light,
                    ),
                  ),
                  Text(
                    versionInfo.latestVersion,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () {
                ref.read(versionCheckProvider.notifier).dismissUpdate();
                Navigator.of(context).pop();
              },
              child: Text(
                'Later',
                style: TextStyle(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral600Light,
                ),
              ),
            ),
          FilledButton(
            onPressed: () => _launchUpdate(context, versionInfo.downloadUrl),
            child: Text(l10n.updateNow),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdate(BuildContext context, String? url) async {
    final updateUrl = url ??
        'https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker';

    try {
      final uri = Uri.parse(updateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open update link'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open update link. Please try again.'),
          ),
        );
      }
    }
  }
}

