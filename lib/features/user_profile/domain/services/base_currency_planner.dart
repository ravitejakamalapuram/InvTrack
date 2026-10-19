import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';

/// What to do about the base currency when a user signs in (A31).
enum BaseCurrencyAction {
  /// Show the profile's currency on this device.
  adoptProfile,

  /// The profile has none yet; store the currency this device already uses.
  saveDevice,

  /// A new user: ask them to confirm [BaseCurrencyPlan.currency].
  propose,

  /// Change nothing.
  none,
}

class BaseCurrencyPlan {
  const BaseCurrencyPlan(this.action, [this.currency]);

  final BaseCurrencyAction action;
  final String? currency;
}

/// Decides how the base currency and the user's profile line up.
///
/// [inUseCurrency] is the currency this device already shows for the user, or
/// null on a device with no stored currency and no data. A user with data
/// keeps that currency: swapping it for the detected or stored one would
/// reinterpret records without a currency (A03-F1). When the device and the
/// profile disagree and the device has data, nothing changes.
BaseCurrencyPlan planBaseCurrency({
  required UserProfileEntity? profile,
  required String? inUseCurrency,
  required String countryCode,
}) {
  if (profile != null) {
    final stored = profile.preferredCurrency;
    if (inUseCurrency == null || inUseCurrency == stored) {
      return BaseCurrencyPlan(BaseCurrencyAction.adoptProfile, stored);
    }
    return const BaseCurrencyPlan(BaseCurrencyAction.none);
  }
  if (inUseCurrency != null) {
    return BaseCurrencyPlan(BaseCurrencyAction.saveDevice, inUseCurrency);
  }
  final proposed = LocaleDetectionService.proposeCurrencyForCountry(
    countryCode,
  );
  if (proposed == null) return const BaseCurrencyPlan(BaseCurrencyAction.none);
  return BaseCurrencyPlan(BaseCurrencyAction.propose, proposed);
}
