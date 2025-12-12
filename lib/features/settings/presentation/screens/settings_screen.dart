import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/features/data/presentation/providers/data_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
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
          const Divider(),
          _buildSectionHeader('Account'),
          _buildAccountSection(context, ref),
          // Debug sections - only show in debug mode AND for guest users
          ..._buildDebugSections(context, ref),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          title: const Text('Enable Passcode'),
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
          ListTile(
            title: const Text('Change Passcode'),
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
          if (securityState.isBiometricAvailable)
            SwitchListTile(
              title: const Text('Enable Biometrics'),
              subtitle: const Text('Face ID / Touch ID'),
              value: securityState.isBiometricEnabled,
              onChanged: (bool value) {
                securityNotifier.toggleBiometrics(value);
              },
            ),
        ],
      ],
    );
  }

  Widget _buildSyncSection(BuildContext context, WidgetRef ref) {
    final isOfflineAsync = ref.watch(isOfflineProvider);
    final authState = ref.watch(authStateProvider);

    // Default to online if still loading
    final isOffline = isOfflineAsync.maybeWhen(
      data: (offline) => offline,
      orElse: () => false,
    );

    return Column(
      children: [
        ListTile(
          title: const Text('Cloud Sync Status'),
          subtitle: Text(isOffline ? 'Offline - changes will sync when online' : 'Connected to Google Sheets'),
          leading: Icon(
            isOffline ? Icons.cloud_off : Icons.cloud_done,
            color: isOffline ? Colors.orange : Colors.green,
          ),
          trailing: authState.when(
            data: (user) => user != null && !user.isGuest
                ? TextButton(
                    onPressed: () async {
                      final result = await ref.read(dataControllerProvider).refreshFromCloud();
                      if (context.mounted) {
                        result.when(
                          success: (_) => AppFeedback.showSuccess(context, 'Synced with cloud'),
                          failure: (error) => AppFeedback.showError(context, error),
                        );
                      }
                    },
                    child: const Text('Refresh'),
                  )
                : const Text('Sign in required', style: TextStyle(color: Colors.grey)),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const SizedBox.shrink();
        }

        // Guest/Demo mode user
        if (user.isGuest) {
          return Column(
            children: [
              ListTile(
                title: const Text('Demo Mode'),
                subtitle: const Text('Your data is stored locally only'),
                leading: const Icon(Icons.person_outline, color: Colors.grey),
              ),
              ListTile(
                title: const Text('Connect to Google Account'),
                subtitle: const Text('Sync your data across devices'),
                leading: const Icon(Icons.link, color: Colors.blue),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showConnectToGoogleDialog(context, ref),
              ),
            ],
          );
        }

        // Google user
        return Column(
          children: [
            ListTile(
              title: Text(user.displayName ?? user.email),
              subtitle: user.displayName != null ? Text(user.email) : null,
              leading: CircleAvatar(
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            ListTile(
              title: const Text('Sign Out'),
              leading: const Icon(Icons.logout, color: Colors.red),
              onTap: () async {
                // Use DataController to handle sign out (clears local data and signs out)
                final result = await ref.read(dataControllerProvider).signOut();
                if (context.mounted) {
                  result.when(
                    success: (_) => AppFeedback.showSuccess(context, 'Signed out successfully'),
                    failure: (error) => AppFeedback.showError(context, error),
                  );
                }
              },
            ),
          ],
        );
      },
      loading: () => const ListTile(
        title: Text('Loading...'),
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const ListTile(
        title: Text('Error loading account'),
        leading: Icon(Icons.error, color: Colors.red),
      ),
    );
  }

  Future<void> _showConnectToGoogleDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Google Account?'),
        content: const Text(
          'Your local data will be uploaded to Google Sheets. '
          'You can access your investments from any device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Use DataController to handle the connection
    final result = await ref.read(dataControllerProvider).connectToGoogle();

    if (!context.mounted) return;

    result.when(
      success: (_) {
        AppFeedback.showSuccess(context, 'Successfully connected to Google!');
      },
      failure: (error) {
        AppFeedback.showError(context, error);
      },
    );
  }

  List<Widget> _buildDebugSections(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return [];

    final authState = ref.watch(authStateProvider);
    final isGuest = authState.maybeWhen(
      data: (user) => user?.isGuest ?? true,
      orElse: () => true,
    );

    return [
      // Sync section only for Google users (not guests)
      if (!isGuest) ...[
        const Divider(),
        _buildSectionHeader('Google Sheets Sync (Debug)'),
        _buildSyncSection(context, ref),
      ],
      const Divider(),
      _buildSectionHeader('Developer Options'),
      ListTile(
        title: const Text('Seed Demo Data'),
        subtitle: const Text('Add sample investments'),
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
            await ref.read(seedDataStateProvider.notifier).seedData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo data seeded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
      ),
    ];
  }
}
