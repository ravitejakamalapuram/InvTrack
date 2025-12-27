/// User profile card for settings header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

/// Displays user profile info at top of settings.
class UserProfileCard extends ConsumerWidget {
  const UserProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final displayName = user.displayName ?? 'User';
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
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photoUrl == null
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryLight,
                            AppColors.primaryLight.withValues(alpha: 0.7),
                          ],
                        )
                      : null,
                  image: photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? Center(
                        child: Text(
                          _getInitials(displayName),
                          style: AppTypography.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
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
                        color: isDark ? Colors.white : AppColors.neutral900Light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      email,
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      ),
                    ),
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

