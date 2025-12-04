import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/seed_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/sync/presentation/providers/sync_provider.dart';
import 'package:inv_tracker/features/sync/presentation/screens/sync_issues_screen.dart';

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
          _buildSectionHeader('Account'),
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
            },
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
          ],
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
}
