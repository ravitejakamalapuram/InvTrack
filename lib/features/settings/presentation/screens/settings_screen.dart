/// Main settings screen - hub for all settings sub-screens.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/screens/income_guardian_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/debug_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/user_profile_card.dart';

/// Main settings hub screen with navigation to sub-sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // PERFORMANCE: Use ref.select to rebuild only when specific fields change
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final hasPin = ref.watch(securityProvider.select((s) => s.hasPin));
    final isBiometricEnabled = ref.watch(
      securityProvider.select((s) => s.isBiometricEnabled),
    );
    final isDebugEnabled = ref.watch(debugModeProvider);
    final isIncomeGuardianEnabled = ref.watch(isIncomeGuardianEnabledProvider);

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
              // Extract to separate widget to avoid full-screen rebuilds
              const _CurrencyTile(),
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

          // Income Guardian: hidden until something generates expected
          // cash flows (A42).
          if (isIncomeGuardianEnabled)
            SettingsSection(
              title: l10n.incomeGuardianSettings,
              children: [
                SettingsNavTile(
                  icon: Icons.security,
                  iconColor: AppColors.successLight,
                  title: l10n.incomeGuardianSettings,
                  subtitle: l10n.incomeGuardianSettingsSubtitle,
                  onTap: () => _navigateTo(
                    context,
                    const IncomeGuardianSettingsScreen(),
                  ),
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

          // Developer (only visible when debug mode is enabled). The
          // kReleaseMode check compiles the debug screen out of release builds.
          if (!kReleaseMode && isDebugEnabled)
            SettingsSection(
              title: l10n.developer,
              children: [
                SettingsNavTile(
                  icon: Icons.bug_report,
                  iconColor: Colors.orange,
                  title: l10n.debugSettings,
                  subtitle: l10n.advancedToolsAndDiagnostics,
                  onTap: () =>
                      _navigateTo(context, const DebugSettingsScreen()),
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

  // Currency picker moved to _CurrencyTile widget to avoid full-screen rebuilds

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final isGuest = ref.read(authStateProvider).value?.isAnonymous ?? false;
    if (isGuest) return _handleGuestSignOut(context, ref);

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _signOut(ref);
  }

  /// A guest cannot sign back in to an anonymous account, so signing out
  /// loses their data. Offer linking and a backup first.
  Future<void> _handleGuestSignOut(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<_GuestSignOutChoice>(
      context: context,
      builder: (_) => const _GuestSignOutDialog(),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _GuestSignOutChoice.linkGoogle:
        await GoogleSignInHandler(ref: ref, context: context).handleSignIn();
      case _GuestSignOutChoice.exportBackup:
        try {
          await ref.read(dataExportServiceProvider)?.exportAndShare();
        } catch (e, st) {
          if (!context.mounted) return;
          ErrorHandler.handle(e, st, context: context, showFeedback: true);
        }
      case _GuestSignOutChoice.signOut:
        await _signOut(ref);
    }
  }

  Future<void> _signOut(WidgetRef ref) async {
    // The Analytics and Crashlytics user IDs are cleared when the auth state
    // empties (userIdentitySyncProvider).
    await ref.read(authRepositoryProvider).signOut();
  }
}

enum _GuestSignOutChoice { linkGoogle, exportBackup, signOut }

/// Sign-out dialog for guest (anonymous) users. Linking is the primary
/// action, export the secondary one, and plain sign-out is styled as
/// destructive.
class _GuestSignOutDialog extends StatelessWidget {
  const _GuestSignOutDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    void choose(_GuestSignOutChoice choice) => Navigator.pop(context, choice);

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: errorColor),
      title: Text(l10n.guestSignOutTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.guestSignOutMessage),
          SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => choose(_GuestSignOutChoice.linkGoogle),
            child: Text(l10n.guestSignOutLinkGoogle),
          ),
          SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => choose(_GuestSignOutChoice.exportBackup),
            child: Text(l10n.guestSignOutExportBackup),
          ),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => choose(_GuestSignOutChoice.signOut),
            child: Text(l10n.guestSignOutConfirm),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// Currency tile widget - extracted to avoid full-screen rebuilds
/// Only this widget rebuilds when currency switch status changes
class _CurrencyTile extends ConsumerStatefulWidget {
  const _CurrencyTile();

  @override
  ConsumerState<_CurrencyTile> createState() => _CurrencyTileState();
}

class _CurrencyTileState extends ConsumerState<_CurrencyTile> {
  /// Starts a base-currency change. If older records without a currency were
  /// never confirmed, the user is asked first, on this tile's context (the
  /// currency sheet is already closed by then).
  void _switchCurrency(String newCurrency) {
    ref
        .read(currencySwitchProvider.notifier)
        .switchCurrencyDebounced(
          newCurrency,
          askLegacyCurrency: (currency) async {
            if (!mounted) return null;
            return askLegacyCurrencyBeforeSwitch(
              context,
              currency: currency,
              newCurrency: newCurrency,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(settingsProvider.select((s) => s.currency));
    final currencySwitchStatus = ref.watch(currencySwitchProvider);

    // Listen for currency switch completion (moved from SettingsScreen)
    ref.listen<CurrencySwitchStatus>(currencySwitchProvider, (previous, next) {
      // Safe null handling: targetCurrency should always be set but guard against null
      final targetCurrency = next.targetCurrency ?? 'Unknown';

      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.currencySwitchedSuccessfully(targetCurrency)),
            backgroundColor: AppColors.successLight,
            duration: const Duration(seconds: 2),
          ),
        );
        // Reset state after showing success (guard with mounted check)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(currencySwitchProvider.notifier).reset();
          }
        });
      } else if (next.isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currencySwitchFailureMessage(l10n, next)),
            backgroundColor: AppColors.errorLight,
            // The blocked-switch explanation is longer; give time to read it.
            duration: Duration(
              seconds: next.unstampedLegacyCurrency != null ? 8 : 3,
            ),
            action: SnackBarAction(
              label: l10n.retry,
              textColor: Colors.white,
              onPressed: () {
                // Only retry if targetCurrency is not null
                if (next.targetCurrency != null) {
                  _switchCurrency(next.targetCurrency!);
                }
              },
            ),
          ),
        );
        // Reset state after showing error (guard with mounted check)
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            ref.read(currencySwitchProvider.notifier).reset();
          }
        });
      }
    });

    final tile = SettingsValueTile(
      icon: Icons.currency_exchange_rounded,
      iconColor: AppColors.successLight,
      title: l10n.currency,
      value: currencySwitchStatus.isBusy ? l10n.loading : currency,
      trailing: currencySwitchStatus.isBusy
          ? Semantics(
              label:
                  currencySwitchStatus.fetchedRates != null &&
                      currencySwitchStatus.totalRates != null
                  ? l10n.loadingProgress(
                      currencySwitchStatus.fetchedRates ?? 0,
                      currencySwitchStatus.totalRates ?? 0,
                    )
                  : l10n.loading,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryLight,
                  ),
                  value: currencySwitchStatus.progress,
                ),
              ),
            )
          : null,
      onTap: currencySwitchStatus.isBusy
          ? null
          : () => _showCurrencyPicker(context, ref),
    );

    // Wrap in Semantics when disabled to announce disabled state to screen readers
    if (currencySwitchStatus.isBusy) {
      return Semantics(
        button: true,
        enabled: false,
        label: '${l10n.currency}, ${l10n.loading}',
        child: tile,
      );
    }

    return tile;
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get all supported currencies with localized names
    final supportedCurrencies = {
      'USD': l10n.currencyUSD,
      'EUR': l10n.currencyEUR,
      'GBP': l10n.currencyGBP,
      'INR': l10n.currencyINR,
      'JPY': l10n.currencyJPY,
      'CAD': l10n.currencyCAD,
      'AUD': l10n.currencyAUD,
      'CHF': l10n.currencyCHF,
      'CNY': l10n.currencyCNY,
      'SGD': l10n.currencySGD,
      'HKD': l10n.currencyHKD,
      'BRL': l10n.currencyBRL,
      'MXN': l10n.currencyMXN,
      'ZAR': l10n.currencyZAR,
    };

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectCurrency, style: AppTypography.h3),
            SizedBox(height: AppSpacing.md),
            ...supportedCurrencies.entries.map((entry) {
              final code = entry.key;
              final name = entry.value;
              final isSelected = settings.currency == code;

              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? AppColors.primaryLight
                      : (isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral400Light),
                ),
                title: Text(name),
                onTap: () {
                  // Close the bottom sheet
                  Navigator.pop(context);
                  // Trigger currency switch with debouncing (prevents race conditions)
                  _switchCurrency(code);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
