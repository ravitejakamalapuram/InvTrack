import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Persistent notice, with a Withdraw action, for as long as a
/// `deletionRequests/{uid}` document exists. Unlike the one-off sign-in
/// notice, it stays on screen, so a user who keeps adding data knows the
/// deletion job will remove it. Shows nothing otherwise, or while this
/// device is running the deletion itself.
class DeletionRequestBanner extends ConsumerStatefulWidget {
  const DeletionRequestBanner({super.key});

  @override
  ConsumerState<DeletionRequestBanner> createState() =>
      _DeletionRequestBannerState();
}

class _DeletionRequestBannerState extends ConsumerState<DeletionRequestBanner> {
  bool _withdrawing = false;

  @override
  Widget build(BuildContext context) {
    // Watch everything first so the live status keeps flowing while hidden.
    final live = ref.watch(deletionRequestStatusProvider).value;
    final held = ref.watch(deletionWithdrawalProvider);
    final deleting = ref.watch(deletionInProgressProvider);

    // Loading, a listen error or no request reads as nothing to tell, unless
    // a withdrawal has not reached the server yet.
    final status = live == null || live == DeletionRequestStatus.none
        ? held
        : live;
    if (deleting || status == null || status == DeletionRequestStatus.none) {
      return const SizedBox.shrink();
    }
    return _buildBanner(context, status);
  }

  Widget _buildBanner(BuildContext context, DeletionRequestStatus status) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = status == DeletionRequestStatus.pending
        ? l10n.deletionRequestBannerPending
        : l10n.deletionRequestBannerScheduled;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorLight.withValues(alpha: 0.3)),
      ),
      // The message (a live region) and the Withdraw button stay separate
      // nodes: Flutter keeps a focusable button out of a merged node anyway.
      child: Semantics(
        container: true,
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber,
              color: AppColors.errorLight,
              size: 20,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: AppTypography.small.copyWith(
                    color: isDark ? Colors.white70 : AppColors.neutral700Light,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _withdrawing ? null : () => _withdraw(status),
              child: Text(l10n.deletionScheduledWithdraw),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _withdraw(DeletionRequestStatus shown) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _withdrawing = true);
    final withdrawn = await ref
        .read(deletionWithdrawalProvider.notifier)
        .withdraw(shown);
    if (mounted) setState(() => _withdrawing = false);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          withdrawn
              ? l10n.deletionRequestWithdrawn
              : l10n.deletionRequestWithdrawFailed,
        ),
      ),
    );
  }
}
