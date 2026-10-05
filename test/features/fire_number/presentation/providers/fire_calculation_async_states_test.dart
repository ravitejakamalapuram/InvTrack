/// A28 / ARCH-05: the FIRE number must never be computed from a portfolio
/// that failed to load. A stats load error must reach the FIRE card and
/// screen as an error, not as loading for as long as Riverpod retries it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

final _loadError = Exception('permission-denied');

final _settings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: DateTime.now().year - 30,
  targetFireAge: 45,
  isSetupComplete: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test('fireCalculationProvider reports a stats load error, not loading, under '
      'the default retry policy', () async {
    final container = ProviderContainer(
      overrides: [
        fireSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
        // The FIRE inputs come from the converted snapshot (A11), which
        // needs the base currency.
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.error(_loadError),
        ),
      ],
      // Production (main.dart) keeps Riverpod's default retry policy.
    );
    addTearDown(container.dispose);

    final sub = container.listen(fireCalculationProvider, (_, _) {});
    // Sample across several retry rounds: the state must stay an error
    // and never show a FIRE number computed from an empty portfolio.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final state = sub.read();
      expect(state.isLoading, isFalse, reason: 'sample $i: $state');
      expect(state.hasError, isTrue, reason: 'sample $i: $state');
      expect(state.error, same(_loadError));
      expect(state.hasValue, isFalse);
    }
  });
}
