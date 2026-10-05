// A10 (#754): every stats provider a screen reads must include the current
// value of open investments as their terminal inflow, converted to the base
// currency first (money rules 2, 3 and 4). Today is pinned to 2026-10-02 so
// the CALC-01 golden values apply; see current_value_golden_test.dart.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

DateTime _addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months, d.day);

InvestmentEntity _inv(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  double? rate,
  InterestPayoutMode? payout,
  String currency = 'INR',
  double? currentValue,
  DateTime? currentValueDate,
  bool isArchived = false,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  expectedRate: rate,
  compoundingFrequency: CompoundingFrequency.quarterly,
  interestPayoutMode: payout,
  currency: currency,
  currentValue: currentValue,
  currentValueDate: currentValueDate,
  isArchived: isArchived,
);

CashFlowEntity _cf(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: currency,
);

final _payoutFd = _inv(
  's2',
  InvestmentType.fixedDeposit,
  rate: 7.5,
  payout: InterestPayoutMode.periodic,
);
final _payoutFdFlows = [
  _cf('s2', CashFlowType.invest, 100000, DateTime(2024, 10, 2)),
  for (var k = 1; k <= 8; k++)
    _cf(
      's2',
      CashFlowType.income,
      1875,
      _addMonths(DateTime(2024, 10, 2), 3 * k),
    ),
];

final _closedP2p = _inv(
  'p2p',
  InvestmentType.p2pLending,
  status: InvestmentStatus.closed,
);
final _cumulativeFd = _inv(
  'fd',
  InvestmentType.fixedDeposit,
  rate: 7,
  payout: InterestPayoutMode.cumulative,
);
final _portfolioFlows = [
  _cf('p2p', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
  _cf('p2p', CashFlowType.returnFlow, 112000, DateTime(2025, 1, 1)),
  _cf('fd', CashFlowType.invest, 500000, DateTime(2026, 4, 1)),
];

ProviderContainer _container({
  required List<InvestmentEntity> investments,
  required List<CashFlowEntity> cashFlows,
  List<InvestmentEntity> archived = const [],
  List<CashFlowEntity> archivedFlows = const [],
  String baseCurrency = 'INR',
  CurrencyConversionService? conversion,
}) {
  return ProviderContainer(
    overrides: [
      valuationDateProvider.overrideWithValue(DateTime(2026, 10, 2)),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(cashFlows)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(archived)),
      for (final inv in investments)
        cashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in cashFlows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      for (final inv in archived)
        archivedCashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in archivedFlows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      currencyCodeProvider.overrideWith((ref) => baseCurrency),
      currencyConversionServiceProvider.overrideWithValue(
        conversion ?? MockCurrencyConversionService(),
      ),
    ],
  );
}

/// Keeps an auto-disposed provider (and the streams it watches) alive for the
/// rest of the test.
void _keep(ProviderContainer container, ProviderListenable<Object?> provider) {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
}

/// Waits until the investment and cash flow streams have emitted, so the
/// portfolio providers do not start from their loading state.
Future<void> _settle(ProviderContainer container) async {
  _keep(container, validCashFlowsProvider);
  for (var i = 0; i < 50; i++) {
    if (container.read(validCashFlowsProvider).hasValue) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('cash flows did not load');
}

/// Reads a provider that depends on stream providers once they have emitted.
Future<T> _read<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = container.listen(provider, (_, _) {});
  try {
    for (var i = 0; i < 50; i++) {
      final value = container.read(provider);
      if (value.hasValue && !value.isLoading) return value.requireValue;
      if (value.hasError) throw value.error!;
      await Future<void>.delayed(Duration.zero);
    }
    fail('provider did not resolve');
  } finally {
    sub.close();
  }
}

/// The user's base currency, switchable from a test.
class _BaseCurrency extends Notifier<String> {
  @override
  String build() => 'INR';

  void select(String code) => state = code;
}

final _baseCurrencyProvider = NotifierProvider<_BaseCurrency, String>(
  _BaseCurrency.new,
);

/// Holds back every conversion dated [heldDay] while [hold] is set.
class _HeldRateService extends MockCurrencyConversionService {
  _HeldRateService(this.heldDay);

  final DateTime heldDay;
  Completer<void>? hold;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    final gate = hold;
    if (gate != null &&
        requests.values.any(
          (r) =>
              r.date != null &&
              r.date!.year == heldDay.year &&
              r.date!.month == heldDay.month &&
              r.date!.day == heldDay.day,
        )) {
      await gate.future;
    }
    return super.batchConvertHistorical(requests: requests, to: to);
  }
}

/// No CHF rate can be found, now or last known.
class _NoChfRates extends MockCurrencyConversionService {
  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    if (requests.values.any((r) => r.from == 'CHF')) {
      throw StateError('rate service unavailable');
    }
    return super.batchConvertHistorical(requests: requests, to: to);
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => from == 'CHF' ? null : super.getLastKnownRate(from: from, to: to);
}

void main() {
  test(
    'detail stats of a payout FD include its principal (CALC-01 S2)',
    () async {
      final container = _container(
        investments: [_payoutFd],
        cashFlows: _payoutFdFlows,
      );
      addTearDown(container.dispose);

      _keep(container, multiCurrencyInvestmentStatsProvider('s2'));
      final stats = await container.read(
        multiCurrencyInvestmentStatsProvider('s2').future,
      );

      expect(stats.currentValue, 100000);
      expect(stats.xirr, closeTo(0.077137789, 1e-6));
      expect(stats.moic, closeTo(1.15, 1e-9));
      expect(stats.absoluteReturn, closeTo(15.0, 1e-9));
      expect(stats.netCashFlow, -85000, reason: 'cash-only, unchanged');
    },
  );

  test('portfolio XIRR and MOIC include open terminal values (S4)', () async {
    final container = _container(
      investments: [_closedP2p, _cumulativeFd],
      cashFlows: _portfolioFlows,
    );
    addTearDown(container.dispose);

    await _settle(container);
    _keep(container, multiCurrencyGlobalStatsProvider);
    final global = await container.read(
      multiCurrencyGlobalStatsProvider.future,
    );
    expect(global.currentValue, closeTo(517800.77, 0.005));
    expect(global.xirr, closeTo(0.087328923, 1e-6));
    expect(global.moic, closeTo(1.049667953, 1e-6));
    expect(global.currentValueIsEstimate, isTrue);
    expect(global.missingValueCount, 0);

    _keep(container, multiCurrencyOpenStatsProvider);
    final open = await container.read(multiCurrencyOpenStatsProvider.future);
    expect(open.currentValue, closeTo(517800.77, 0.005));
    expect(open.missingValueCount, 0);

    _keep(container, multiCurrencyClosedStatsProvider);
    final closed = await container.read(
      multiCurrencyClosedStatsProvider.future,
    );
    expect(closed.currentValue, isNull);
    // 1.12^(365/366) − 1: 2024 is a leap year.
    expect(closed.xirr, closeTo(0.119653256, 1e-6));
  });

  test(
    'a value in another currency is converted to the base currency',
    () async {
      final usdGold = _inv(
        'gold',
        InvestmentType.gold,
        currency: 'USD',
        currentValue: 1250,
        currentValueDate: DateTime(2026, 10, 1),
      );
      final container = _container(
        investments: [usdGold],
        cashFlows: [
          _cf(
            'gold',
            CashFlowType.invest,
            1000,
            DateTime(2025, 10, 1),
            currency: 'USD',
          ),
        ],
      );
      addTearDown(container.dispose);

      _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
      final stats = await container.read(
        multiCurrencyInvestmentStatsProvider('gold').future,
      );
      // Mock rate: 1 USD = 83 INR.
      expect(stats.currentValue, closeTo(1250 * 83.0, 0.005));
      expect(stats.totalInvested, closeTo(1000 * 83.0, 0.005));
      expect(stats.moic, closeTo(1.25, 1e-9));
      expect(stats.currentValueIsEstimate, isFalse);
    },
  );

  test('an open holding without a value is reported as missing', () async {
    final gold = _inv('gold', InvestmentType.gold);
    final container = _container(
      investments: [gold, _cumulativeFd],
      cashFlows: [
        _cf('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
        _cf('fd', CashFlowType.invest, 500000, DateTime(2026, 4, 1)),
      ],
    );
    addTearDown(container.dispose);

    await _settle(container);
    _keep(container, multiCurrencyGlobalStatsProvider);
    final global = await container.read(
      multiCurrencyGlobalStatsProvider.future,
    );
    expect(global.missingValueCount, 1);
    _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
    final single = await container.read(
      multiCurrencyInvestmentStatsProvider('gold').future,
    );
    expect(single.missingValueCount, 1);
    expect(single.currentValue, isNull);
  });

  test('archived open investments use their current value too', () async {
    final archivedGold = _inv(
      'old-gold',
      InvestmentType.gold,
      currentValue: 125000,
      currentValueDate: DateTime(2026, 10, 1),
      isArchived: true,
    );
    final container = _container(
      investments: const [],
      cashFlows: const [],
      archived: [archivedGold],
      archivedFlows: [
        _cf('old-gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
      ],
    );
    addTearDown(container.dispose);

    _keep(container, multiCurrencyArchivedInvestmentStatsProvider('old-gold'));
    final stats = await container.read(
      multiCurrencyArchivedInvestmentStatsProvider('old-gold').future,
    );
    expect(stats.currentValue, 125000);
    expect(stats.xirr, closeTo(0.25, 1e-6));
  });

  test('list card stats and XIRR include the terminal value', () async {
    final container = _container(
      investments: [_payoutFd],
      cashFlows: _payoutFdFlows,
    );
    addTearDown(container.dispose);

    final basic = await _read(container, investmentBasicStatsProvider('s2'));
    expect(basic.currentValue, 100000);
    expect(basic.moic, closeTo(1.15, 1e-9));

    _keep(container, investmentXirrProvider('s2'));
    final xirr = await container.read(investmentXirrProvider('s2').future);
    expect(xirr.value, closeTo(0.077137789, 1e-6));

    _keep(container, activeInvestmentXirrResultMapProvider);
    final xirrMap = await container.read(
      activeInvestmentXirrResultMapProvider.future,
    );
    expect(xirrMap['s2']!.value, closeTo(0.077137789, 1e-6));
  });

  test('list cards, XIRR and the detail screen convert a value in another '
      'currency the same way', () async {
    // Tagged USD, bought in INR. The USD value is converted before it is
    // added to the INR flow (money rule 2), on every path, so the card, the
    // sort and the detail screen agree (A13).
    final gold = _inv(
      'gold',
      InvestmentType.gold,
      currency: 'USD',
      currentValue: 1200,
      currentValueDate: DateTime(2026, 9, 1),
    );
    final container = _container(
      investments: [gold],
      cashFlows: [
        _cf('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ],
    );
    addTearDown(container.dispose);

    // Mock rate: 1 USD = 83 INR, so the value is ₹99,600.
    final basic = await _read(container, investmentBasicStatsProvider('gold'));
    expect(basic.currentValue, closeTo(1200 * 83.0, 0.005));
    expect(basic.missingValueCount, 0);
    expect(basic.moic, closeTo(0.996, 1e-9));

    // 0.996^(365/334) − 1
    _keep(container, activeInvestmentXirrResultMapProvider);
    final xirrMap = await container.read(
      activeInvestmentXirrResultMapProvider.future,
    );
    expect(xirrMap['gold']!.value, closeTo(-0.004370445, 1e-6));

    _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
    final detail = await container.read(
      multiCurrencyInvestmentStatsProvider('gold').future,
    );
    expect(detail.currentValue, closeTo(1200 * 83.0, 0.005));
    expect(detail.moic, closeTo(0.996, 1e-9));
    expect(detail.xirr, closeTo(-0.004370445, 1e-6));
  });

  test('a value that cannot be converted counts as missing, never as a '
      'native amount under the base symbol', () async {
    // Bought in INR, valued in CHF. The INR flow needs no rate; the CHF
    // value has none. (Flows with no rate fail visibly instead; A13.)
    final chfGold = _inv(
      'gold',
      InvestmentType.gold,
      currency: 'CHF',
      currentValue: 1250,
      currentValueDate: DateTime(2026, 10, 1),
    );
    final container = _container(
      investments: [chfGold],
      cashFlows: [
        _cf('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
      ],
      conversion: _NoChfRates(),
    );
    addTearDown(container.dispose);

    _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
    final stats = await container.read(
      multiCurrencyInvestmentStatsProvider('gold').future,
    );
    expect(stats.currentValue, isNull);
    expect(stats.missingValueCount, 1);

    final basic = await _read(container, investmentBasicStatsProvider('gold'));
    expect(basic.currentValue, isNull);
    expect(basic.missingValueCount, 1);
  });

  test('list cards never pair new cash flows with a current value that is '
      'still being converted', () async {
    // A USD P2P loan valued at its outstanding principal. Recording a
    // principal return changes the flows and the value together; while
    // today's rate for the new value is pending, the card must keep the old
    // pair (or load), never the new flows with the old value.
    final loan = _inv('loan', InvestmentType.p2pLending, currency: 'USD');
    final invest = _cf(
      'loan',
      CashFlowType.invest,
      1000,
      DateTime(2025, 10, 2),
      currency: 'USD',
    );
    final principalBack = _cf(
      'loan',
      CashFlowType.returnFlow,
      400,
      DateTime(2026, 6, 1),
      currency: 'USD',
    );
    final flows = StreamController<List<CashFlowEntity>>.broadcast();
    addTearDown(flows.close);
    final rates = _HeldRateService(DateTime(2026, 10, 2));
    final container = ProviderContainer(
      overrides: [
        valuationDateProvider.overrideWithValue(DateTime(2026, 10, 2)),
        allInvestmentsProvider.overrideWith((ref) => Stream.value([loan])),
        allCashFlowsStreamProvider.overrideWith((ref) => flows.stream),
        archivedInvestmentsProvider.overrideWith(
          (ref) => Stream.value(const <InvestmentEntity>[]),
        ),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencyConversionServiceProvider.overrideWithValue(rates),
      ],
    );
    addTearDown(container.dispose);
    _keep(container, activeInvestmentBasicStatsMapProvider);
    Future<void> flush() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    flows.add([invest]);
    await flush();
    final before = container.read(investmentBasicStatsProvider('loan'));
    // Mock rate: 1 USD = 83 INR.
    expect(before.requireValue.currentValue, closeTo(1000 * 83.0, 0.005));

    rates.hold = Completer<void>();
    flows.add([invest, principalBack]);
    await flush();
    final during = container.read(investmentBasicStatsProvider('loan'));
    if (during.hasValue) {
      final stats = during.requireValue;
      final oldPair =
          stats.totalReturned == 0 &&
          (stats.currentValue! - 1000 * 83.0).abs() < 0.005;
      final newPair =
          (stats.totalReturned - 400 * 83.0).abs() < 0.005 &&
          (stats.currentValue! - 600 * 83.0).abs() < 0.005;
      expect(
        oldPair || newPair,
        isTrue,
        reason:
            'returned ${stats.totalReturned} with value ${stats.currentValue}',
      );
    }

    rates.hold!.complete();
    await flush();
    final after = container.read(investmentBasicStatsProvider('loan'));
    expect(after.requireValue.totalReturned, closeTo(400 * 83.0, 0.005));
    expect(after.requireValue.currentValue, closeTo(600 * 83.0, 0.005));
    expect(after.requireValue.moic, closeTo(1.0, 1e-9));
  });

  test('after a base-currency switch, list cards stay loading until the '
      'current values are converted too', () async {
    // The INR flow converts at once; today's rate for the value is held.
    final rates = _HeldRateService(DateTime(2026, 10, 2));
    final container = ProviderContainer(
      overrides: [
        valuationDateProvider.overrideWithValue(DateTime(2026, 10, 2)),
        allInvestmentsProvider.overrideWith(
          (ref) => Stream.value([_cumulativeFd]),
        ),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.value([
            _cf('fd', CashFlowType.invest, 500000, DateTime(2026, 4, 1)),
          ]),
        ),
        archivedInvestmentsProvider.overrideWith(
          (ref) => Stream.value(const <InvestmentEntity>[]),
        ),
        currencyCodeProvider.overrideWith(
          (ref) => ref.watch(_baseCurrencyProvider),
        ),
        currencyConversionServiceProvider.overrideWithValue(rates),
      ],
    );
    addTearDown(container.dispose);
    _keep(container, activeInvestmentBasicStatsMapProvider);
    Future<void> flush() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    await flush();
    final inInr = container.read(investmentBasicStatsProvider('fd'));
    // 1.0175^(4 × 184/365) on ₹5,00,000.
    expect(inInr.requireValue.currentValue, closeTo(517800.771973, 0.005));

    rates.hold = Completer<void>();
    container.read(_baseCurrencyProvider.notifier).select('USD');
    await flush();
    // Never the INR value (or INR flows) under the $ symbol (rule 2).
    final pending = container.read(investmentBasicStatsProvider('fd'));
    expect(pending.hasValue, isFalse, reason: '$pending');

    rates.hold!.complete();
    await flush();
    // Mock rate: 1 USD = 83 INR.
    final inUsd = container.read(investmentBasicStatsProvider('fd'));
    expect(inUsd.requireValue.totalInvested, closeTo(500000 / 83, 0.005));
    expect(inUsd.requireValue.currentValue, closeTo(517800.771973 / 83, 0.005));
    expect(inUsd.requireValue.moic, closeTo(1.035601544, 1e-6));
  });
}
