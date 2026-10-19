import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/services/base_currency_planner.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';

final baseCurrencyReconcilerProvider = Provider<BaseCurrencyReconciler>(
  BaseCurrencyReconciler.new,
);

/// Lines the base currency up with the user's profile (A31).
///
/// [reconcile] applies what needs no question and returns the plan, so the
/// caller only has to ask when the plan is [BaseCurrencyAction.propose]; the
/// answer goes to [confirm]. A thrown error (for example an unreachable
/// server) means the account's data could not be checked, so nothing changes.
class BaseCurrencyReconciler {
  BaseCurrencyReconciler(this._ref);

  final Ref _ref;

  Future<BaseCurrencyPlan> reconcile(
    String userId, {
    required bool Function() isCurrent,
  }) async {
    // The device shows a currency "in use" only when this user already has
    // investments. The saved currency is device-wide, so it may have been
    // left by another account, and a fresh install shows only the default.
    // The local cache can be empty on a new device, so ask the server.
    final hasData = await _ref
        .read(investmentRepositoryProvider)
        .hasAnyInvestmentOnServer();
    // Read the profile and the shown currency only now: a currency the user
    // switched to while the server was answering must not be overwritten.
    final repository = _ref.read(userProfileRepositoryProvider(userId));
    final profile = await repository.getProfile();
    if (!isCurrent()) {
      return const BaseCurrencyPlan(BaseCurrencyAction.none);
    }
    final shown = _ref.read(settingsProvider).currency;
    final locale = _ref.read(deviceLocaleProvider);
    final plan = planBaseCurrency(
      profile: profile,
      inUseCurrency: hasData ? shown : null,
      // No fallback to 'US': a missing country proposes nothing (money rule 1).
      countryCode: locale.countryCode ?? '',
    );
    final currency = plan.currency;
    if (currency == null) {
      return const BaseCurrencyPlan(BaseCurrencyAction.none);
    }
    switch (plan.action) {
      case BaseCurrencyAction.adoptProfile:
        if (currency != shown) {
          await _ref.read(settingsProvider.notifier).setCurrency(currency);
        }
      case BaseCurrencyAction.saveDevice:
        await _save(userId, currency);
      case BaseCurrencyAction.propose:
      case BaseCurrencyAction.none:
        break;
    }
    return plan;
  }

  /// Shows [currency] and stores it on the profile after the user confirmed it.
  Future<void> confirm(String userId, String currency) async {
    await _ref.read(settingsProvider.notifier).setCurrency(currency);
    await _save(userId, currency);
  }

  Future<void> _save(String userId, String currency) {
    final locale = _ref.read(deviceLocaleProvider);
    return _ref
        .read(userProfileRepositoryProvider(userId))
        .saveProfile(
          UserProfileEntity.fromDetectedLocale(
            userId: userId,
            countryCode: locale.countryCode ?? '',
            languageCode: locale.languageCode,
            currency: currency,
          ),
        );
  }
}
