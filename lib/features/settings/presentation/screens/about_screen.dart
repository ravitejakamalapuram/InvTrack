/// About screen with app info, legal documents, and support.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:url_launcher/url_launcher.dart';

/// App version info - matches pubspec.yaml version: 3.5.1+19
const String _appVersion = '3.25.1';
const String _buildNumber = '63';

/// Screen showing app information and legal documents.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('About', style: AppTypography.h3)),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.md),

          // App logo and name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryLight,
                        AppColors.primaryLight.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.trending_up, size: 40, color: Colors.white),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'InvTrack',
                  style: AppTypography.h2.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  'Version $_appVersion ($_buildNumber)',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.xl),

          // Legal section
          SettingsSection(
            title: 'Legal',
            children: [
              SettingsNavTile(
                icon: Icons.privacy_tip,
                iconColor: Colors.purple,
                title: 'Privacy Policy',
                onTap: () =>
                    _openLegalScreen(context, 'Privacy Policy', _privacyPolicy),
              ),
              SettingsNavTile(
                icon: Icons.description,
                iconColor: Colors.purple,
                title: 'Terms of Service',
                onTap: () => _openLegalScreen(
                  context,
                  'Terms of Service',
                  _termsOfService,
                ),
              ),
            ],
          ),

          // Support section
          SettingsSection(
            title: 'Support',
            children: [
              SettingsNavTile(
                icon: Icons.help_outline,
                iconColor: Colors.blue,
                title: 'Help & FAQ',
                onTap: () => _openHelpPage(context),
              ),
              SettingsNavTile(
                icon: Icons.email_outlined,
                iconColor: Colors.teal,
                title: 'Contact Support',
                subtitle: 'invtrack_support@googlegroups.com',
                onTap: () => _openSupportEmail(context),
              ),
            ],
          ),

          // Made with love
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                'Made with ❤️ for smart investors',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral400Light,
                ),
              ),
            ),
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _openLegalScreen(BuildContext context, String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LegalScreen(title: title, content: content),
      ),
    );
  }

  /// Opens the Help & FAQ page (GitHub repository wiki or docs)
  Future<void> _openHelpPage(BuildContext context) async {
    const helpUrl = 'https://github.com/ravitejakamalapuram/InvTrack#readme';
    final uri = Uri.parse(helpUrl);

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy URL to clipboard
        if (!context.mounted) return;
        await _copyToClipboardWithFeedback(
          context,
          helpUrl,
          'Help URL copied to clipboard',
        );
      }
    } catch (e) {
      // Fallback: copy URL to clipboard
      if (!context.mounted) return;
      await _copyToClipboardWithFeedback(
        context,
        helpUrl,
        'Help URL copied to clipboard',
      );
    }
  }

  /// Opens the email client for support
  Future<void> _openSupportEmail(BuildContext context) async {
    const supportEmail = 'invtrack_support@googlegroups.com';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQueryParameters({
        'subject': 'InvTrack Support Request (v$_appVersion)',
        'body': 'Please describe your issue or question:\n\n',
      }),
    );

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri);
      } else {
        // Fallback: copy email to clipboard
        if (!context.mounted) return;
        await _copyToClipboardWithFeedback(
          context,
          supportEmail,
          'Email copied to clipboard: $supportEmail',
        );
      }
    } catch (e) {
      // Fallback: copy email to clipboard
      if (!context.mounted) return;
      await _copyToClipboardWithFeedback(
        context,
        supportEmail,
        'Email copied to clipboard: $supportEmail',
      );
    }
  }

  /// Copies text to clipboard and shows success feedback
  Future<void> _copyToClipboardWithFeedback(
    BuildContext context,
    String text,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Encodes query parameters for mailto URI
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}

const String _privacyPolicy = '''
**Privacy Policy**

Last updated: December 05, 2025

1. **Introduction**
   InvTracker ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how your personal information is collected, used, and disclosed by InvTracker.

2. **Data Collection**
   We do not collect any personal data on our servers. All your investment data is stored locally on your device. If you choose to sign in with Google, your authentication token is used solely to verify your identity and is not stored on our servers.

3. **Data Usage**
   Your data is used exclusively to provide you with investment tracking features. We do not sell, trade, or rent your personal identification information to others.

4. **Security**
   We use administrative, technical, and physical security measures to help protect your personal information. While we have taken reasonable steps to secure the personal information you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable.

5. **Contact Us**
   If you have questions about this Privacy Policy, please contact us at invtrack_support@googlegroups.com.
''';

const String _termsOfService = '''
**Terms of Service**

Last updated: December 05, 2025

1. **Agreement to Terms**
   By using our mobile application, you agree to be bound by these Terms of Service.

2. **Intellectual Property**
   The Service and its original content, features, and functionality are the exclusive property of InvTracker.

3. **Disclaimer**
   Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind.

4. **Investment Advice**
   InvTracker is a tracking tool only. We do not provide financial, investment, or tax advice. Always consult with qualified professionals.

5. **Governing Law**
   These Terms shall be governed by the laws of California, United States.
''';
