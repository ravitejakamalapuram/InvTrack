/// Main settings screen - hub for all settings sub-screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/user_profile_card.dart';

/// Main settings hub screen with navigation to sub-sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    final securityState = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTypography.h3)),
      body: ListView(
        children: [
          // User Profile Card
          const UserProfileCard(),

          // Appearance & Preferences
          SettingsSection(
            title: 'General',
            children: [
              SettingsNavTile(
                icon: Icons.palette,
                iconColor: Colors.purple,
                title: 'Appearance',
                subtitle: _getThemeModeLabel(themeMode),
                onTap: () =>
                    _navigateTo(context, const AppearanceSettingsScreen()),
              ),
              SettingsValueTile(
                icon: Icons.currency_exchange_rounded,
                iconColor: AppColors.successLight,
                title: 'Currency',
                value: settings.currency,
                onTap: () => _showCurrencyPicker(context, ref),
              ),
            ],
          ),

          // Security & Privacy
          SettingsSection(
            title: 'Security',
            children: [
              SettingsNavTile(
                icon: securityState.hasPin ? Icons.lock : Icons.lock_open,
                iconColor: securityState.hasPin ? AppColors.successLight : null,
                title: 'App Lock',
                subtitle: securityState.hasPin
                    ? 'PIN enabled${securityState.isBiometricEnabled ? ' • Biometrics on' : ''}'
                    : 'Protect your data',
                onTap: () =>
                    _navigateTo(context, const SecuritySettingsScreen()),
              ),
            ],
          ),

          // Notifications
          SettingsSection(
            title: 'Notifications',
            children: [
              SettingsNavTile(
                icon: Icons.notifications,
                iconColor: Colors.orange,
                title: 'Notifications',
                subtitle: 'Reminders & summaries',
                onTap: () =>
                    _navigateTo(context, const NotificationsSettingsScreen()),
              ),
            ],
          ),

          // Data & Account
          SettingsSection(
            title: 'Data & Account',
            children: [
              SettingsNavTile(
                icon: Icons.folder,
                iconColor: Colors.blue,
                title: 'Data & Account',
                subtitle: 'Import, export, backup & delete',
                onTap: () => _navigateTo(context, const DataManagementScreen()),
              ),
            ],
          ),

          // About & Legal
          SettingsSection(
            title: 'About',
            children: [
              SettingsNavTile(
                icon: Icons.info,
                iconColor: Colors.grey,
                title: 'About InvTrack',
                subtitle: 'Version, legal & support',
                onTap: () => _navigateTo(context, const AboutScreen()),
              ),
            ],
          ),

          // Sign Out
          SettingsSection(
            children: [
              SettingsNavTile(
                icon: Icons.logout,
                iconColor: AppColors.errorLight,
                title: 'Sign Out',
                showChevron: false,
                onTap: () => _handleSignOut(context, ref),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get all supported currencies from LocaleDetectionService
    final supportedCurrencies = {
      'USD': 'US Dollar (\$)',
      'EUR': 'Euro (€)',
      'GBP': 'British Pound (£)',
      'INR': 'Indian Rupee (₹)',
      'JPY': 'Japanese Yen (¥)',
      'CAD': 'Canadian Dollar (C\$)',
      'AUD': 'Australian Dollar (A\$)',
      'CHF': 'Swiss Franc (CHF)',
      'CNY': 'Chinese Yuan (¥)',
      'SGD': 'Singapore Dollar (S\$)',
      'HKD': 'Hong Kong Dollar (HK\$)',
      'BRL': 'Brazilian Real (R\$)',
      'MXN': 'Mexican Peso (MX\$)',
      'ZAR': 'South African Rand (R)',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral600Dark : AppColors.neutral300Light,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Select Currency', style: AppTypography.h4),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: supportedCurrencies.entries.map((entry) {
                    final code = entry.key;
                    final name = entry.value;
                    final isSelected = settings.currency == code;

                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.primaryLight)
                          : null,
                      onTap: () {
                        notifier.setCurrency(code);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear user identity from Analytics and Crashlytics
              ref.read(analyticsServiceProvider).setUserId(null);
              ref.read(crashlyticsServiceProvider).clearUserIdentifier();
              ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
