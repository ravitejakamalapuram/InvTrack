/// Security settings screen with PIN and biometric options.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// Screen for managing security settings.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final securityNotifier = ref.read(securityProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Security', style: AppTypography.h3)),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // App Lock section
          SettingsSection(
            title: 'App Lock',
            footer: securityState.hasPin
                ? 'Your app is protected with a PIN'
                : 'Add a PIN to protect your data',
            children: [
              SettingsToggleTile(
                icon: securityState.hasPin ? Icons.lock : Icons.lock_open,
                iconColor: securityState.hasPin ? AppColors.successLight : null,
                title: 'Enable App Lock',
                subtitle: securityState.hasPin
                    ? 'PIN required to open app'
                    : 'Protect with a 4-digit PIN',
                value: securityState.hasPin,
                onChanged: (value) =>
                    _handlePinToggle(context, value, securityNotifier),
              ),
            ],
          ),

          // Biometric section (only show if PIN is set)
          if (securityState.hasPin && securityState.isBiometricAvailable)
            SettingsSection(
              title: 'Quick Unlock',
              footer: 'Use biometrics for faster access',
              children: [
                SettingsToggleTile(
                  icon: Icons.fingerprint,
                  iconColor: securityState.isBiometricEnabled
                      ? AppColors.primaryLight
                      : null,
                  title: 'Face ID / Touch ID',
                  subtitle: 'Unlock with biometrics',
                  value: securityState.isBiometricEnabled,
                  onChanged: (value) =>
                      securityNotifier.toggleBiometrics(value),
                ),
              ],
            ),

          // PIN management (only show if PIN is set)
          if (securityState.hasPin)
            SettingsSection(
              title: 'Manage PIN',
              children: [
                SettingsNavTile(
                  icon: Icons.pin,
                  iconColor: Colors.blue,
                  title: 'Change PIN',
                  subtitle: 'Update your security code',
                  onTap: () => _handleChangePin(context, securityNotifier),
                ),
              ],
            ),

          // Security info
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your investment data is stored locally on this device and is never uploaded to external servers.',
                      style: AppTypography.small.copyWith(
                        color: isDark
                            ? Colors.white70
                            : AppColors.neutral700Light,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _handlePinToggle(
    BuildContext context,
    bool enable,
    SecurityNotifier notifier,
  ) {
    if (enable) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PasscodeScreen(mode: PasscodeMode.create),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PasscodeScreen(
            mode: PasscodeMode.verify,
            onSuccess: () => notifier.removePin(),
          ),
        ),
      );
    }
  }

  void _handleChangePin(BuildContext context, SecurityNotifier notifier) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PasscodeScreen(
          mode: PasscodeMode.verify,
          onSuccess: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    const PasscodeScreen(mode: PasscodeMode.create),
              ),
            );
          },
        ),
      ),
    );
  }
}
