import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/premium/data/services/premium_service.dart';

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService(ref.watch(sharedPreferencesProvider));
});

final isPremiumProvider = NotifierProvider<PremiumNotifier, bool>(
  PremiumNotifier.new,
);

class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(premiumServiceProvider).isPremium;

  Future<void> setPremium(bool value) async {
    await ref.read(premiumServiceProvider).setPremium(value);
    state = value;
  }
}
