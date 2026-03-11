/// Main settings screen - hub for all settings sub-screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/debug_settings_screen.dart';
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
    final l10n = AppLocalizations.of(context);

    // PERFORMANCE: Use ref.select to rebuild only when specific fields change
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final currency = ref.watch(settingsProvider.select((s) => s.currency));
    final hasPin = ref.watch(securityProvider.select((s) => s.hasPin));
    final isBiometricEnabled = ref.watch(
      securityProvider.select((s) => s.isBiometricEnabled),
    );
    final isDebugEnabled = ref.watch(debugModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings, style: AppTypography.h3)),
      body: ListView(
        children: [
          // User Profile Card
          const UserProfileCard(),

          // Appearance & Preferences
          SettingsSection(
            title: l10n.general,
            children: [
              SettingsNavTile(
                icon: Icons.palette,
                iconColor: Colors.purple,
                title: l10n.appearance,
                subtitle: _getThemeModeLabel(themeMode, l10n),
                onTap: () =>
                    _navigateTo(context, const AppearanceSettingsScreen()),
              ),
              SettingsValueTile(
                icon: Icons.currency_exchange_rounded,
                iconColor: AppColors.successLight,
                title: l10n.currency,
                value: currency,
                onTap: () => _showCurrencyPicker(context, ref),
              ),
            ],
          ),

          // Security & Privacy
          SettingsSection(
            title: l10n.security,
            children: [
              SettingsNavTile(
                icon: hasPin ? Icons.lock : Icons.lock_open,
                iconColor: hasPin ? AppColors.successLight : null,
                title: l10n.appLock,
                subtitle: hasPin
                    ? '${l10n.pinEnabled}${isBiometricEnabled ? ' • ${l10n.biometricsOn}' : ''}'
                    : l10n.protectYourData,
                onTap: () =>
                    _navigateTo(context, const SecuritySettingsScreen()),
              ),
            ],
          ),

          // Notifications
          SettingsSection(
            title: l10n.notifications,
            children: [
              SettingsNavTile(
                icon: Icons.notifications,
                iconColor: Colors.orange,
                title: l10n.notifications,
                subtitle: l10n.remindersAndSummaries,
                onTap: () =>
                    _navigateTo(context, const NotificationsSettingsScreen()),
              ),
            ],
          ),

          // Data & Account
          SettingsSection(
            title: l10n.dataAndAccount,
            children: [
              SettingsNavTile(
                icon: Icons.folder,
                iconColor: Colors.blue,
                title: l10n.dataAndAccount,
                subtitle: l10n.importExportBackupDelete,
                onTap: () => _navigateTo(context, const DataManagementScreen()),
              ),
            ],
          ),

          // About & Legal
          SettingsSection(
            title: l10n.about,
            children: [
              SettingsNavTile(
                icon: Icons.info,
                iconColor: Colors.grey,
                title: l10n.aboutInvTrack,
                subtitle: l10n.versionLegalSupport,
                onTap: () => _navigateTo(context, const AboutScreen()),
              ),
            ],
          ),

          // Developer (only visible when debug mode is enabled)
          if (isDebugEnabled)
            SettingsSection(
              title: l10n.developer,
              children: [
                SettingsNavTile(
                  icon: Icons.bug_report,
                  iconColor: Colors.orange,
                  title: l10n.debugSettings,
                  subtitle: l10n.advancedToolsAndDiagnostics,
                  onTap: () => _navigateTo(context, const DebugSettingsScreen()),
                ),
              ],
            ),

          // Sign Out
          SettingsSection(
            children: [
              SettingsNavTile(
                icon: Icons.logout,
                iconColor: AppColors.errorLight,
                title: l10n.signOut,
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

  String _getThemeModeLabel(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                  color: isDark
                      ? AppColors.neutral600Dark
                      : AppColors.neutral300Light,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.selectCurrency, style: AppTypography.h4),
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
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: AppColors.primaryLight,
                            )
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear user identity from Analytics and Crashlytics
              ref.read(analyticsServiceProvider).setUserId(null);
              ref.read(crashlyticsServiceProvider).clearUserIdentifier();
              ref.read(authRepositoryProvider).signOut();
            },
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }
}
