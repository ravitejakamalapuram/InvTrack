/// Empty state widget for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

/// Empty state shown when there are no investments.
class OverviewEmptyState extends StatelessWidget {
  const OverviewEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Column(
      children: [
        // Welcome section
        GlassCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.2),
                      primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to InvTracker!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track what you invested and what came back. See your real returns.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Getting started steps
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 16),
              _GettingStartedStep(
                number: 1,
                title: 'Add Investment',
                subtitle: 'Create your first investment entry',
                icon: Icons.add_circle_outline,
              ),
              const SizedBox(height: 12),
              _GettingStartedStep(
                number: 2,
                title: 'Record Cash Flows',
                subtitle: 'Track money in and out over time',
                icon: Icons.swap_vert_rounded,
              ),
              const SizedBox(height: 12),
              _GettingStartedStep(
                number: 3,
                title: 'See Your Returns',
                subtitle: 'XIRR, MOIC, and net position',
                icon: Icons.insights_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Call to action hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap the "Add Investment" button below to begin!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.neutral800Light,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A step in the getting started guide.
class _GettingStartedStep extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;

  const _GettingStartedStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
      ],
    );
  }
}

/// Error card for the overview screen.
class OverviewErrorCard extends StatelessWidget {
  final String error;

  const OverviewErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text('Error: $error'),
        ],
      ),
    );
  }
}

