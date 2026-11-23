import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_metal_rates_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';
import 'package:inv_tracker/features/investment/domain/repositories/metal_rates_repository.dart';
import 'package:inv_tracker/features/investment/domain/services/metal_rate_quoter.dart';

final metalRatesRepositoryProvider = Provider<MetalRatesRepository>(
  (ref) => FirestoreMetalRatesRepository(ref.watch(firestoreProvider)),
);

/// Today's stored rates. Read once per screen visit, not streamed: they
/// change once a day.
final metalRatesProvider = FutureProvider.autoDispose<MetalRates?>(
  (ref) => ref.watch(metalRatesRepositoryProvider).latest(),
);

typedef MetalRateKey = ({Metal metal, String currency});

/// The price per gram of [MetalRateKey.metal] in [MetalRateKey.currency], or
/// null when there is no fresh one. Rupees try the India rate first, which
/// needs no conversion; everything else converts the dollar price with the
/// app's live exchange rate, and gives no price if that rate is unavailable.
final metalRateQuoteProvider = FutureProvider.autoDispose
    .family<MetalRateQuote?, MetalRateKey>((ref, key) async {
      final rates = await ref.watch(metalRatesProvider.future);
      if (rates == null) return null;
      final now = DateTime.now().toUtc();
      final direct = MetalRateQuoter.quote(
        rates: rates,
        metal: key.metal,
        currency: key.currency,
        now: now,
      );
      final code = key.currency.trim().toUpperCase();
      if (direct != null || code.isEmpty || code == 'USD') return direct;
      try {
        final service = ref.read(currencyConversionServiceProvider);
        if (service == null) return null;
        final usdTo = await service.getLiveRate('USD', code);
        // The exchange-rate request can take a while: judge freshness at the
        // time it finishes, not when it started.
        return MetalRateQuoter.quote(
          rates: rates,
          metal: key.metal,
          currency: code,
          now: DateTime.now().toUtc(),
          usdToCurrency: usdTo,
        );
      } catch (_) {
        return null;
      }
    });
