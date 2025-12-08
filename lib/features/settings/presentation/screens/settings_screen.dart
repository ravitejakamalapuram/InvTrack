import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/seed_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/sync/presentation/providers/sync_provider.dart';
import 'package:inv_tracker/features/sync/presentation/screens/sync_issues_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/import_provider.dart';
import 'package:inv_tracker/features/premium/presentation/widgets/premium_gate.dart';
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
          _buildSectionHeader('Sync'),
          ListTile(
            title: const Text('Sync Issues'),
            leading: const Icon(Icons.sync_problem, color: Colors.orange),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SyncIssuesScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Sync Now'),
            leading: const Icon(Icons.sync, color: Colors.blue),
            trailing: ref.watch(syncStatusProvider).when(
              data: (lastSynced) => lastSynced != null 
                  ? Text(DateFormat.Hm().format(lastSynced), style: AppTypography.caption)
                  : const SizedBox(),
              loading: () => const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2)
              ),
              error: (err, stack) => const Icon(Icons.error, color: Colors.red),
            ),
            onTap: () {
               ref.read(syncStatusProvider.notifier).sync();
            },
          ),
          const Divider(),
          _buildSectionHeader('Portfolio'),
          _buildPortfolioSection(context, ref),
          const Divider(),
          _buildSectionHeader('Account'),
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          PremiumGate(
            child: ListTile(
              title: const Text('Export to CSV'),
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
                }
              },
            ),
          ),
          PremiumGate(
            child: ListTile(
              title: const Text('Import from CSV'),
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              trailing: ref.watch(importStateProvider).isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(importStateProvider.notifier).importCsv();
                final state = ref.read(importStateProvider);
                
                if (context.mounted) {
                   state.when(
                    data: (result) {
                      if (result != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported: ${result.successCount} success, ${result.failureCount} failed.\n${result.message}',
                            ),
                            backgroundColor: result.failureCount > 0 ? Colors.orange : Colors.green,
                          ),
                        );
                      }
                    },
                    error: (err, stack) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import failed: $err'), backgroundColor: Colors.red),
                      );
                    },
                    loading: () {},
                  );
                }
              },
            ),
          ),
          if (kDebugMode) ...[
            const Divider(),
            _buildSectionHeader('Developer Options'),
            ListTile(
              title: const Text('Seed Data (10k Transactions)'),
              leading: const Icon(Icons.science, color: Colors.purple),
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seeding data... This may take a while.')),
                );
                await ref.read(seedServiceProvider).seedData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data seeded successfully!')),
                  );
                }
              },
            ),
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

  Widget _buildPortfolioSection(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return portfoliosAsync.when(
      data: (portfolios) {
        if (portfolios.isEmpty) {
          return ListTile(
            title: const Text('No portfolios'),
            subtitle: const Text('Create your first portfolio'),
            leading: const Icon(Icons.folder_outlined, color: Colors.grey),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showCreatePortfolioDialog(context, ref),
            ),
          );
        }

        return Column(
          children: [
            ...portfolios.map((portfolio) => ListTile(
              title: Text(portfolio.name),
              subtitle: Text('Created ${DateFormat.yMMMd().format(portfolio.createdAt)}'),
              leading: const Icon(Icons.folder, color: Colors.blue),
              trailing: portfolios.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDeletePortfolio(context, ref, portfolio.id, portfolio.name),
                    )
                  : null,
              onTap: () => _showRenamePortfolioDialog(context, ref, portfolio.id, portfolio.name),
            )),
            ListTile(
              title: const Text('Add Portfolio'),
              leading: const Icon(Icons.add, color: Colors.green),
              onTap: () => _showCreatePortfolioDialog(context, ref),
            ),
          ],
        );
      },
      loading: () => const ListTile(
        title: Text('Loading portfolios...'),
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => ListTile(
        title: const Text('Error loading portfolios'),
        subtitle: Text('$e'),
        leading: const Icon(Icons.error, color: Colors.red),
      ),
    );
  }

  void _showCreatePortfolioDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Portfolio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Portfolio Name',
            hintText: 'e.g., My Investments',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(portfolioProvider.notifier).createPortfolio(controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenamePortfolioDialog(BuildContext context, WidgetRef ref, String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Portfolio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Portfolio Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(portfolioProvider.notifier).renamePortfolio(id, controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePortfolio(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Portfolio?'),
        content: Text('Are you sure you want to delete "$name"? This will also delete all investments and transactions in this portfolio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(portfolioProvider.notifier).deletePortfolio(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
