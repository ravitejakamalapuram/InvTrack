import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/premium/data/services/premium_service.dart';

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService(ref.watch(sharedPreferencesProvider));
});

final isPremiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier(ref.watch(premiumServiceProvider));
});

class PremiumNotifier extends StateNotifier<bool> {
  final PremiumService _service;

  PremiumNotifier(this._service) : super(_service.isPremium);

  Future<void> setPremium(bool value) async {
    await _service.setPremium(value);
    state = value;
  }
}
