import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
import 'package:inv_tracker/features/premium/presentation/providers/premium_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          // User Info Section
          _buildUserInfoSection(context, ref),
          const Divider(),
          _buildSectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(settings.themeMode.toString().split('.').last.toUpperCase()),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) {
                  notifier.setThemeMode(newValue);
                }
              },
              items: ThemeMode.values.map<DropdownMenuItem<ThemeMode>>((ThemeMode value) {
                return DropdownMenuItem<ThemeMode>(
                  value: value,
                  child: Text(value.toString().split('.').last.toUpperCase()),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          _buildSectionHeader('Preferences'),
          ListTile(
            title: const Text('Currency'),
            subtitle: Text(settings.currency),
            trailing: DropdownButton<String>(
              value: settings.currency,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  notifier.setCurrency(newValue);
                }
              },
              items: <String>['USD', 'EUR', 'GBP', 'INR', 'JPY']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          _buildSectionHeader('Security'),
          _buildSecuritySection(context, ref),
          // Notifications section
          const Divider(),
          _buildSectionHeader('Notifications'),
          _buildNotificationsSection(context, ref),
          // Data Management section
          const Divider(),
          _buildSectionHeader('Data Management'),
          ListTile(
            title: const Text('Export Investments'),
            subtitle: const Text('Download as CSV'),
            leading: const Icon(Icons.download, color: Colors.green),
            trailing: ref.watch(exportStateProvider).isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await ref.read(exportStateProvider.notifier).exportCsv();
              final state = ref.read(exportStateProvider);
              if (state.hasError && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: ${state.error}')),
                );
              } else {
                ref.read(analyticsServiceProvider).logExportGenerated(format: 'csv');
              }
            },
          ),
          ListTile(
            title: const Text('Import Investments'),
            subtitle: const Text('Import from CSV template'),
            leading: const Icon(Icons.upload_file, color: Colors.blue),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BulkImportScreen(),
                ),
              );
            },
          ),
          if (kDebugMode) ...[
            const Divider(),
            _buildSectionHeader('Developer Options'),
            ListTile(
              title: const Text('Reset Premium Status'),
              leading: const Icon(Icons.restore, color: Colors.orange),
              onTap: () async {
                await ref.read(isPremiumProvider.notifier).setPremium(false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Premium status reset to FREE')),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Seed Demo Data'),
              subtitle: const Text('Add sample investments for screenshots'),
              leading: const Icon(Icons.dataset, color: Colors.teal),
              trailing: ref.watch(seedDataStateProvider).isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Seed Demo Data?'),
                    content: const Text(
                      'This will add 8 sample investments with realistic cash flows. '
                      'Use this for app store screenshots.\n\n'
                      'Note: Existing data will NOT be deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Seed Data'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final result = await ref.read(seedDataStateProvider.notifier).seedData();
                  if (context.mounted && result != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Seeded ${result.investments} investments with ${result.cashFlows} cash flows'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Test Notification'),
              subtitle: const Text('Send a test notification'),
              leading: const Icon(Icons.notifications_active, color: Colors.blue),
              onTap: () async {
                final notificationService = ref.read(notificationServiceProvider);
                final success = await notificationService.showTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Test notification sent! Check your notification shade.'
                          : 'Permission denied. Please enable notifications in settings.'),
                      backgroundColor: success ? Colors.blue : Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
          const Divider(),
          _buildSectionHeader('About'),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip, color: Colors.purple),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LegalScreen(
                    title: 'Privacy Policy',
                    content: '''
**Privacy Policy**

Last updated: December 05, 2025

1. **Introduction**
   InvTracker ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how your personal information is collected, used, and disclosed by InvTracker.

2. **Data Collection**
   We do not collect any personal data on our servers. All your investment data is stored locally on your device. If you choose to sign in with Google, your authentication token is used solely to verify your identity and is not stored on our servers.

3. **Data Usage**
   Your data is used exclusively to provide you with investment tracking features. We do not sell, trade, or rent your personal identification information to others.

4. **Security**
   We use administrative, technical, and physical security measures to help protect your personal information. While we have taken reasonable steps to secure the personal information you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable, and no method of data transmission can be guaranteed against any interception or other type of misuse.

5. **Contact Us**
   If you have questions or comments about this Privacy Policy, please contact us at support@invtracker.com.
                    ''',
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            leading: const Icon(Icons.description, color: Colors.purple),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LegalScreen(
                    title: 'Terms of Service',
                    content: '''
**Terms of Service**

Last updated: December 05, 2025

1. **Agreement to Terms**
   By viewing or using our mobile application, you agree to be bound by these Terms of Service. If you disagree with any part of the terms, then you may not access the Service.

2. **Intellectual Property**
   The Service and its original content, features, and functionality are and will remain the exclusive property of InvTracker and its licensors.

3. **Links to Other Web Sites**
   Our Service may contain links to third-party web sites or services that are not owned or controlled by InvTracker. InvTracker has no control over, and assumes no responsibility for, the content, privacy policies, or practices of any third party web sites or services.

4. **Termination**
   We may terminate or suspend access to our Service immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.

5. **Disclaimer**
   Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis. The Service is provided without warranties of any kind, whether express or implied.

6. **Governing Law**
   These Terms shall be governed and construed in accordance with the laws of California, United States, without regard to its conflict of law provisions.
                    ''',
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0 (Build 1)'),
            leading: const Icon(Icons.info, color: Colors.grey),
          ),
          // Sign Out at the end
          const Divider(),
          _buildSectionHeader('Account'),
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              ref.read(analyticsServiceProvider).setUserId(null);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final securityNotifier = ref.read(securityProvider.notifier);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('App Lock'),
          subtitle: Text(
            securityState.hasPin
                ? 'Require PIN to open app'
                : 'Protect your data with a PIN',
          ),
          secondary: Icon(
            securityState.hasPin ? Icons.lock : Icons.lock_open,
            color: securityState.hasPin ? Colors.green : null,
          ),
          value: securityState.hasPin,
          onChanged: (bool value) {
            if (value) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PasscodeScreen(mode: PasscodeMode.create),
                ),
              );
            } else {
              // Verify PIN before disabling
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PasscodeScreen(
                    mode: PasscodeMode.verify,
                    onSuccess: () {
                      securityNotifier.removePin();
                    },
                  ),
                ),
              );
            }
          },
        ),
        if (securityState.hasPin) ...[
          if (securityState.isBiometricAvailable)
            SwitchListTile(
              title: const Text('Face ID / Touch ID'),
              subtitle: const Text('Unlock with biometrics'),
              secondary: const Icon(Icons.fingerprint),
              value: securityState.isBiometricEnabled,
              onChanged: (bool value) {
                securityNotifier.toggleBiometrics(value);
              },
            ),
          ListTile(
            title: const Text('Change PIN'),
            leading: const Icon(Icons.pin),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PasscodeScreen(
                    mode: PasscodeMode.verify,
                    onSuccess: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const PasscodeScreen(mode: PasscodeMode.create),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context, WidgetRef ref) {
    final notificationService = ref.watch(notificationServiceProvider);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Income Alerts'),
          subtitle: const Text('Notify when income is recorded'),
          secondary: const Icon(Icons.attach_money, color: Colors.green),
          value: notificationService.incomeAlertsEnabled,
          onChanged: (bool value) async {
            if (value) {
              // Request permissions when enabling
              await notificationService.requestPermissions();
            }
            await notificationService.setIncomeAlertsEnabled(value);
            // Trigger rebuild
            ref.invalidate(notificationServiceProvider);
          },
        ),
        SwitchListTile(
          title: const Text('Weekly Summary'),
          subtitle: const Text('Get a summary every Sunday'),
          secondary: const Icon(Icons.calendar_today, color: Colors.blue),
          value: notificationService.weeklySummaryEnabled,
          onChanged: (bool value) async {
            if (value) {
              await notificationService.requestPermissions();
            }
            await notificationService.setWeeklySummaryEnabled(value);
            ref.invalidate(notificationServiceProvider);
          },
        ),
        SwitchListTile(
          title: const Text('Income Reminders'),
          subtitle: const Text('Remind when income is expected'),
          secondary: const Icon(Icons.notification_important, color: Colors.orange),
          value: notificationService.incomeRemindersEnabled,
          onChanged: (bool value) async {
            if (value) {
              await notificationService.requestPermissions();
            }
            await notificationService.setIncomeRemindersEnabled(value);
            ref.invalidate(notificationServiceProvider);
          },
        ),
        SwitchListTile(
          title: const Text('Maturity Reminders'),
          subtitle: const Text('Remind before investments mature'),
          secondary: const Icon(Icons.event_available, color: Colors.purple),
          value: notificationService.maturityRemindersEnabled,
          onChanged: (bool value) async {
            if (value) {
              await notificationService.requestPermissions();
            }
            await notificationService.setMaturityRemindersEnabled(value);
            ref.invalidate(notificationServiceProvider);
          },
        ),
        SwitchListTile(
          title: const Text('Monthly Summary'),
          subtitle: const Text('Summarize income at end of month'),
          secondary: const Icon(Icons.summarize, color: Colors.teal),
          value: notificationService.monthlySummaryEnabled,
          onChanged: (bool value) async {
            if (value) {
              await notificationService.requestPermissions();
            }
            await notificationService.setMonthlySummaryEnabled(value);
            ref.invalidate(notificationServiceProvider);
          },
        ),
      ],
    );
  }

  Widget _buildUserInfoSection(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final displayName = user.displayName ?? 'User';
        final email = user.email;
        final photoUrl = user.photoUrl;

        return Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.grey.shade600,
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
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      email,
                      style: AppTypography.body.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
