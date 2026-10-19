/// Quiet Overview banner telling guests their data lives only on this device
/// (A43, #786). See design/system/components/GuestLinkBanner.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_link_banner_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class GuestLinkBanner extends ConsumerStatefulWidget {
  const GuestLinkBanner({super.key});

  @override
  ConsumerState<GuestLinkBanner> createState() => _GuestLinkBannerState();
}

class _GuestLinkBannerState extends ConsumerState<GuestLinkBanner> {
  bool _linking = false;

  void _logShownOnce() {
    final seen = ref.read(analyticsOnceProvider);
    if (!seen.add(AnalyticsEvents.guestLinkBannerShown)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(analyticsServiceProvider).logGuestLinkBannerShown();
      }
    });
  }

  Future<void> _link() async {
    ref.read(analyticsServiceProvider).logGuestLinkBannerTapped();
    setState(() => _linking = true);
    try {
      await GoogleSignInHandler(ref: ref, context: context).handleSignIn();
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _dismiss() async {
    ref.read(analyticsServiceProvider).logGuestLinkBannerDismissed();
    try {
      await ref.read(guestLinkBannerDismissProvider.notifier).dismiss();
    } catch (e, st) {
      ErrorHandler.handle(e, st, context: mounted ? context : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(guestLinkBannerVisibleProvider)) {
      return const SizedBox.shrink();
    }
    _logShownOnce();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_upload_outlined, color: accent, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.guestLinkBannerTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.guestLinkBannerMessage,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _linking ? null : _link,
                  child: Text(l10n.guestLinkBannerAction),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.guestLinkBannerDismiss,
            icon: const Icon(Icons.close, size: 20),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
