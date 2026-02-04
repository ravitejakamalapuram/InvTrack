/// Help & FAQ screen with app usage information
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Screen displaying help and frequently asked questions about using the app
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & FAQ', style: AppTypography.h3),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSection(
            'Getting Started',
            [
              _buildFaqItem(
                'How do I add my first investment?',
                'Tap the "+" button on the Investments tab. Enter your investment details including name, amount, date, and category. You can also add transactions later to track your investment growth.',
                isDark,
              ),
              _buildFaqItem(
                'What investment types are supported?',
                'InvTrack supports Stocks, Mutual Funds, Fixed Deposits, Gold, Real Estate, Crypto, and more. You can categorize any investment type.',
                isDark,
              ),
            ],
          ),
          _buildSection(
            'Tracking Returns',
            [
              _buildFaqItem(
                'How are returns calculated?',
                'InvTrack uses XIRR (Extended Internal Rate of Return) to calculate accurate returns considering all your transactions and their timing. This gives you a true picture of your investment performance.',
                isDark,
              ),
              _buildFaqItem(
                'What is XIRR?',
                'XIRR is the industry-standard method for calculating returns on investments with multiple cash flows at different times. It accounts for when you invested and when you withdrew money.',
                isDark,
              ),
            ],
          ),
          _buildSection(
            'Goals',
            [
              _buildFaqItem(
                'How do I set a financial goal?',
                'Go to the Goals tab and tap "+". Enter your goal name, target amount, and deadline. InvTrack will track your progress and show how much you need to save.',
                isDark,
              ),
              _buildFaqItem(
                'Can I link investments to goals?',
                'Yes! When creating or editing a goal, you can allocate specific investments toward that goal. This helps you track progress toward multiple goals simultaneously.',
                isDark,
              ),
            ],
          ),
          _buildSection(
            'Privacy & Security',
            [
              _buildFaqItem(
                'Is my data secure?',
                'Yes! All your data is stored securely in Firebase with encryption. You can also enable app lock with PIN or biometrics for extra security.',
                isDark,
              ),
              _buildFaqItem(
                'What is Privacy Mode?',
                'Privacy Mode hides all financial amounts in the app, showing "•••••" instead. Perfect for when you want to check your portfolio in public. Toggle it from Settings → Appearance.',
                isDark,
              ),
            ],
          ),
          _buildSection(
            'Data Management',
            [
              _buildFaqItem(
                'Can I export my data?',
                'Yes! Go to Settings → Data & Account → Export Data. You can download all your investment data as a ZIP file containing CSV files.',
                isDark,
              ),
              _buildFaqItem(
                'How do I backup my data?',
                'Your data is automatically backed up to Firebase when you\'re signed in. You can also export a local backup anytime from Settings → Data & Account.',
                isDark,
              ),
            ],
          ),
          _buildSection(
            'Multi-Currency Support',
            [
              _buildFaqItem(
                'Can I change my currency?',
                'Yes! Go to Settings → Currency and select from 40+ supported currencies. The app will format all amounts according to your selected currency and locale.',
                isDark,
              ),
              _buildFaqItem(
                'How does currency formatting work?',
                'InvTrack automatically formats numbers based on your currency:\n• Indian Rupee (₹): Shows 1L, 10L, 1Cr\n• USD/EUR/GBP: Shows 100K, 1M, 10M\n• Other currencies use appropriate locale formatting',
                isDark,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Need more help? Contact support@invtracker.com',
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            answer,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.neutral300Dark : AppColors.neutral600Light,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

