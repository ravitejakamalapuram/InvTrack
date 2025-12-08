import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/premium/presentation/providers/premium_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InvTracker Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.star, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              'Unlock Full Potential',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Get access to advanced features and take control of your investments.',
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildFeatureRow(Icons.download, 'CSV Export & Import'),
            _buildFeatureRow(Icons.pie_chart, 'Advanced Analytics (Coming Soon)'),
            _buildFeatureRow(Icons.cloud_sync, 'Unlimited Sync'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  // Mock Purchase
                  await ref.read(isPremiumProvider.notifier).setPremium(true);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Welcome to Premium!')),
                    );
                  }
                },
                child: Text(
                  'Upgrade for \$4.99/mo',
                  style: AppTypography.h3.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight),
          const SizedBox(width: 16),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}
