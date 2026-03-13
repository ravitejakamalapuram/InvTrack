/// User profile card for settings header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Displays user profile info at top of settings.
class UserProfileCard extends ConsumerWidget {
  const UserProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final isAnonymous = user.isAnonymous;
        final displayName = user.displayName ?? (isAnonymous ? 'Guest' : 'User');
        final email = user.email;
        final photoUrl = user.photoUrl;

        return Container(
          margin: EdgeInsets.all(AppSpacing.md),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Avatar with error handling for network images
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          semanticLabel: 'Profile photo of $displayName',
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to initials avatar on network error
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primaryLight.withValues(
                                      alpha: 0.7,
                                    ),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(displayName),
                                  style: AppTypography.h3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight,
                                AppColors.primaryLight.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(displayName),
                              style: AppTypography.h3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTypography.h4.copyWith(
                        color: isDark
                            ? Colors.white
                            : AppColors.neutral900Light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    if (isAnonymous)
                      // Guest mode indicator
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          l10n.guestModeIndicator,
                          style: AppTypography.tiny.copyWith(
                            color: isDark
                                ? Colors.amber.shade200
                                : Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        email,
                        style: AppTypography.small.copyWith(
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral500Light,
                        ),
                      ),
                    if (isAnonymous) ...[
                      SizedBox(height: AppSpacing.sm),
                      // Sign In to Link Account button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/auth/signin'),
                          icon: Icon(
                            Icons.link,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          label: Text(
                            l10n.signInToBackup,
                            style: AppTypography.small.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            side: BorderSide(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: EdgeInsets.all(AppSpacing.md),
        padding: EdgeInsets.all(AppSpacing.xl),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}
