import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/presentation/providers/auth_provider.dart';

/// Settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // User profile section
          Container(
            padding: AppSpacing.screenPadding,
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null ? const Icon(Icons.person, size: 32) : null,
                ),
                AppSpacing.gapHorizontalLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'User', style: Theme.of(context).textTheme.titleMedium),
                      Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapVerticalLg,

          // Settings sections
          _SettingsSection(
            title: 'Data',
            children: [
              _SettingsTile(icon: Icons.cloud_sync, title: 'Google Sheets Sync', subtitle: 'Not connected', onTap: () {}),
              _SettingsTile(icon: Icons.backup, title: 'Backup & Restore', subtitle: 'Manage your data', onTap: () {}),
            ],
          ),

          _SettingsSection(
            title: 'Preferences',
            children: [
              _SettingsTile(icon: Icons.palette, title: 'Theme', subtitle: 'Light', onTap: () {}),
              _SettingsTile(icon: Icons.currency_rupee, title: 'Currency', subtitle: 'INR (₹)', onTap: () {}),
            ],
          ),

          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(icon: Icons.info, title: 'Version', subtitle: '1.0.0', onTap: () {}),
              _SettingsTile(icon: Icons.privacy_tip, title: 'Privacy Policy', onTap: () {}),
            ],
          ),

          AppSpacing.gapVerticalXl,

          // Sign out button
          Padding(
            padding: AppSpacing.screenPaddingHorizontal,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authNotifierProvider.notifier).signOut();
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
            ),
          ),

          AppSpacing.gapVerticalXl,
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary)),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

