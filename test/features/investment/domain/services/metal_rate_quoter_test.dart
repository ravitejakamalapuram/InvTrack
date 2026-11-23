// Today's metal rate for an investment's currency: India sell rate for rupee
// investments, the international rate converted for every other currency.

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';
import 'package:inv_tracker/features/investment/domain/services/metal_rate_quoter.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23, 5);
  final fresh = DateTime.utc(2026, 11, 23, 4);

  MetalRates rates({
    DateTime? inrAt,
    DateTime? usdAt,
    double? inrGold = 12633.66,
    double? usdGold = 116.1,
  }) => MetalRates(
    goldInrSellPerGram: inrGold,
    silverInrSellPerGram: 150.98,
    inrUpdatedAt: inrAt ?? fresh,
    goldUsdPerGram: usdGold,
    silverUsdPerGram: 1.35,
    usdUpdatedAt: usdAt ?? fresh,
  );

  group('rupee investments', () {
    test('use the India selling rate', () {
      final q = MetalRateQuoter.quote(
        rates: rates(),
        metal: Metal.gold,
        currency: 'INR',
        now: now,
        usdToCurrency: 92.75,
      )!;
      expect(q.pricePerGram, 12633.66);
      expect(q.kind, MetalRateKind.indiaSelling);
      expect(q.asOf, fresh);
    });

    test('silver uses the silver rate', () {
      final q = MetalRateQuoter.quote(
        rates: rates(),
        metal: Metal.silver,
        currency: 'INR',
        now: now,
      )!;
      expect(q.pricePerGram, 150.98);
    });

    test(
      'fall back to the converted international rate when India is missing',
      () {
        final q = MetalRateQuoter.quote(
          rates: rates(inrGold: null),
          metal: Metal.gold,
          currency: 'INR',
          now: now,
          usdToCurrency: 92.75,
        )!;
        expect(q.kind, MetalRateKind.international);
        expect(q.pricePerGram, 10768.275); // 116.1 x 92.75, to 4 places
      },
    );

    test('fall back when the India rate is older than 3 days', () {
      final q = MetalRateQuoter.quote(
        rates: rates(inrAt: DateTime.utc(2026, 11, 20, 4, 59)),
        metal: Metal.gold,
        currency: 'INR',
        now: now,
        usdToCurrency: 92.75,
      )!;
      expect(q.kind, MetalRateKind.international);
    });

    test('exactly 3 days old is still fresh', () {
      final q = MetalRateQuoter.quote(
        rates: rates(inrAt: DateTime.utc(2026, 11, 20, 5)),
        metal: Metal.gold,
        currency: 'INR',
        now: now,
      )!;
      expect(q.kind, MetalRateKind.indiaSelling);
    });
  });

  group('other currencies', () {
    test('USD needs no conversion rate', () {
      final q = MetalRateQuoter.quote(
        rates: rates(),
        metal: Metal.gold,
        currency: 'USD',
        now: now,
      )!;
      expect(q.pricePerGram, 116.1);
      expect(q.kind, MetalRateKind.international);
    });

    test('EUR converts the dollar price', () {
      final q = MetalRateQuoter.quote(
        rates: rates(),
        metal: Metal.gold,
        currency: 'EUR',
        now: now,
        usdToCurrency: 0.92,
      )!;
      expect(q.pricePerGram, 106.812); // 116.1 x 0.92
    });

    test(
      'no quote without a conversion rate (never a dollar price under another symbol)',
      () {
        expect(
          MetalRateQuoter.quote(
            rates: rates(),
            metal: Metal.gold,
            currency: 'EUR',
            now: now,
          ),
          isNull,
        );
      },
    );

    test('no quote when the dollar rate is stale', () {
      expect(
        MetalRateQuoter.quote(
          rates: rates(usdAt: DateTime.utc(2026, 11, 19)),
          metal: Metal.gold,
          currency: 'USD',
          now: now,
        ),
        isNull,
      );
    });
  });

  group('bad input', () {
    test('blank currency gives no quote (never defaults to USD)', () {
      expect(
        MetalRateQuoter.quote(
          rates: rates(),
          metal: Metal.gold,
          currency: ' ',
          now: now,
        ),
        isNull,
      );
    });

    for (final bad in [0.0, -5.0, double.nan, double.infinity]) {
      test('rejects a price of $bad', () {
        expect(
          MetalRateQuoter.quote(
            rates: rates(usdGold: bad, inrGold: bad),
            metal: Metal.gold,
            currency: 'INR',
            now: now,
            usdToCurrency: 92.75,
          ),
          isNull,
        );
      });
    }
  });

  group('MetalRates.fromMap', () {
    test('reads both sides', () {
      final r = MetalRates.fromMap({
        'inr': {
          'gold': 12633.66,
          'silver': 150.98,
          'updatedAt': DateTime.utc(2026, 11, 23, 4),
        },
        'usd': {
          'gold': 116.1,
          'silver': 1.35,
          'updatedAt': DateTime.utc(2026, 11, 23, 4),
        },
      })!;
      expect(r.goldInrSellPerGram, 12633.66);
      expect(r.silverUsdPerGram, 1.35);
      expect(r.usdUpdatedAt, DateTime.utc(2026, 11, 23, 4));
    });

    test('a missing side stays empty', () {
      final r = MetalRates.fromMap({
        'usd': {
          'gold': 116.1,
          'silver': 1.35,
          'updatedAt': DateTime.utc(2026, 11, 23, 4),
        },
      })!;
      expect(r.goldInrSellPerGram, isNull);
      expect(r.inrUpdatedAt, isNull);
    });

    test('wrong types are ignored, not thrown', () {
      final r = MetalRates.fromMap({
        'usd': {'gold': 'lots', 'silver': 1.35, 'updatedAt': 'yesterday'},
      })!;
      expect(r.goldUsdPerGram, isNull);
      expect(r.usdUpdatedAt, isNull);
    });
  });
}
