// A13: every screen reads one converted stats snapshot. A USD investment shows
// the same base-currency net and XIRR on its card, its detail screen, the
// archived view and in the list sort order, and the Overview analytics sum
// converted amounts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// USD → INR at 83.8 before 2025 and 88.0 from 2025 on.
class FakeUsdInrConversionService implements CurrencyConversionService {
  static double rateOn(DateTime? date) =>
      date != null && date.isBefore(DateTime(2025)) ? 83.8 : 88.0;

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return 1.0;
    if (from == 'USD' && to == 'INR') return rateOn(date);
    throw ArgumentError('No rate for $from → $to');
  }

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => amount * await getRate(from: from, to: to, date: date);

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {
    for (final e in requests.entries)
      e.key: await convert(
        amount: e.value.amount,
        from: e.value.from,
        to: to,
        date: e.value.date,
      ),
  };

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Offline with no cached rate: the batch lookup fails.
class _OfflineConversionService extends FakeUsdInrConversionService {
  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => throw Exception('offline');
}

/// The batch lookup succeeds but has no rate for USD.
class _MissingRateConversionService extends FakeUsdInrConversionService {
  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => const {};
}

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

InvestmentEntity _investment(
  String id,
  String currency, {
  InvestmentStatus status = InvestmentStatus.closed,
  InvestmentType type = InvestmentType.stocks,
  bool archived = false,
}) => InvestmentEntity(
  id: id,
  name: 'Investment $id',
  type: type,
  status: status,
  currency: currency,
  isArchived: archived,
  createdAt: DateTime(2024, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

CashFlowEntity _flow(
  String id,
  String investmentId,
  CashFlowType type,
  double amount,
  String currency,
  DateTime date,
) => CashFlowEntity(
  id: id,
  investmentId: investmentId,
  type: type,
  amount: amount,
  currency: currency,
  date: date,
  createdAt: date,
);

// $1,000 on 2024-10-01 → $1,100 on 2026-10-01 at 83.8 and 88.0:
// −₹83,800 and +₹96,800, net ₹13,000.00, XIRR (96800 / 83800)^(1/2) − 1.
List<CashFlowEntity> _usdFlows(String investmentId) => [
  _flow(
    '$investmentId-1',
    investmentId,
    CashFlowType.invest,
    1000,
    'USD',
    DateTime(2024, 10, 1),
  ),
  _flow(
    '$investmentId-2',
    investmentId,
    CashFlowType.returnFlow,
    1100,
    'USD',
    DateTime(2026, 10, 1),
  ),
];

// An INR investment with net ₹5,000: ranks above the USD one if the USD
// amounts were left unconverted (net 100), below it once converted.
List<CashFlowEntity> _inrFlows(String investmentId) => [
  _flow(
    '$investmentId-1',
    investmentId,
    CashFlowType.invest,
    50000,
    'INR',
    DateTime(2024, 10, 1),
  ),
  _flow(
    '$investmentId-2',
    investmentId,
    CashFlowType.returnFlow,
    55000,
    'INR',
    DateTime(2026, 10, 1),
  ),
];

const _expectedNet = 13000.0;
const _expectedInvested = 83800.0;
const _expectedReturned = 96800.0;
const _expectedXirr = 0.0747703312412693;

List<Override> _overrides({
  required List<InvestmentEntity> active,
  required List<CashFlowEntity> activeFlows,
  List<InvestmentEntity> archived = const [],
  Map<String, List<CashFlowEntity>> archivedFlows = const {},
  CurrencyConversionService? conversionService,
}) => [
  isAuthenticatedProvider.overrideWith((ref) => true),
  allInvestmentsProvider.overrideWith((ref) => Stream.value(active)),
  archivedInvestmentsProvider.overrideWith((ref) => Stream.value(archived)),
  allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(activeFlows)),
  for (final inv in active)
    cashFlowsByInvestmentProvider(inv.id).overrideWith(
      (ref) => Stream.value([
        for (final cf in activeFlows)
          if (cf.investmentId == inv.id) cf,
      ]),
    ),
  for (final inv in archived)
    archivedCashFlowsByInvestmentProvider(
      inv.id,
    ).overrideWith((ref) => Stream.value(archivedFlows[inv.id] ?? const [])),
  currencyCodeProvider.overrideWith((ref) => 'INR'),
  currencyConversionServiceProvider.overrideWith(
    (ref) => conversionService ?? FakeUsdInrConversionService(),
  ),
];

Future<void> _settle() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('Converted stats snapshot', () {
    test('card, detail and XIRR show the same converted values', () async {
      final container = ProviderContainer(
        overrides: _overrides(
          active: [_investment('usd', 'USD')],
          activeFlows: _usdFlows('usd'),
        ),
      );
      addTearDown(container.dispose);
      container.listen(investmentBasicStatsProvider('usd'), (_, _) {});
      container.listen(multiCurrencyInvestmentStatsProvider('usd'), (_, _) {});
      container.listen(investmentXirrProvider('usd'), (_, _) {});
      await _settle();

      // Card
      final card = container.read(investmentBasicStatsProvider('usd'));
      expect(card.requireValue.netCashFlow, closeTo(_expectedNet, 0.005));
      expect(
        card.requireValue.totalInvested,
        closeTo(_expectedInvested, 0.005),
      );
      expect(
        card.requireValue.totalReturned,
        closeTo(_expectedReturned, 0.005),
      );
      final cardXirr = await container.read(
        investmentXirrProvider('usd').future,
      );
      expect(cardXirr.value, closeTo(_expectedXirr, 1e-6));

      // Detail screen
      final detail = await container.read(
        multiCurrencyInvestmentStatsProvider('usd').future,
      );
      expect(detail.netCashFlow, closeTo(_expectedNet, 0.005));
      expect(detail.xirr, closeTo(_expectedXirr, 1e-6));
    });

    test('archived detail shows the same converted values', () async {
      final archived = _investment('arch', 'USD', archived: true);
      final container = ProviderContainer(
        overrides: _overrides(
          active: const [],
          activeFlows: const [],
          archived: [archived],
          archivedFlows: {'arch': _usdFlows('arch')},
        ),
      );
      addTearDown(container.dispose);
      container.listen(
        multiCurrencyArchivedInvestmentStatsProvider('arch'),
        (_, _) {},
      );
      await _settle();
      final detail = await container.read(
        multiCurrencyArchivedInvestmentStatsProvider('arch').future,
      );
      expect(detail.netCashFlow, closeTo(_expectedNet, 0.005));
      expect(detail.xirr, closeTo(_expectedXirr, 1e-6));
    });

    Future<List<String>> sortedIds(
      ProviderContainer container,
      InvestmentFilter filter,
      InvestmentSort sort,
    ) async {
      final sub = container.listen(filteredInvestmentsProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.setFilter(filter);
      notifier.setSort(sort);
      await _settle();
      return [for (final inv in sub.read().requireValue) inv.id];
    }

    test('active sort by net position uses converted amounts', () async {
      final container = ProviderContainer(
        overrides: _overrides(
          active: [_investment('usd', 'USD'), _investment('inr', 'INR')],
          activeFlows: [..._usdFlows('usd'), ..._inrFlows('inr')],
        ),
      );
      addTearDown(container.dispose);
      expect(
        await sortedIds(
          container,
          InvestmentFilter.all,
          InvestmentSort.netPositionDesc,
        ),
        ['usd', 'inr'],
      );
      expect(
        await sortedIds(
          container,
          InvestmentFilter.all,
          InvestmentSort.totalInvestedDesc,
        ),
        ['usd', 'inr'],
      );
    });

    test('archived sort by net position uses converted amounts', () async {
      final container = ProviderContainer(
        overrides: _overrides(
          active: const [],
          activeFlows: const [],
          archived: [
            _investment('usd', 'USD', archived: true),
            _investment('inr', 'INR', archived: true),
          ],
          archivedFlows: {'usd': _usdFlows('usd'), 'inr': _inrFlows('inr')},
        ),
      );
      addTearDown(container.dispose);
      expect(
        await sortedIds(
          container,
          InvestmentFilter.archived,
          InvestmentSort.netPositionDesc,
        ),
        ['usd', 'inr'],
      );
    });
  });

  group('No rate and no last-known rate', () {
    // Unconverted, the USD flows would show net 100 under the ₹ symbol
    // (CALC-04). Every screen must fail visibly instead. With Riverpod's
    // default retry the screens wait (loading) while the rate is retried;
    // once retries stop they are in their error state.
    for (final entry in <String, CurrencyConversionService>{
      'batch lookup fails': _OfflineConversionService(),
      'rate missing from batch': _MissingRateConversionService(),
    }.entries) {
      for (final retries in [false, true]) {
        final when = retries ? 'while retrying' : 'once retries stop';
        test('${entry.key}, $when: never net 100', () async {
          final archived = _investment('arch', 'USD', archived: true);
          final container = ProviderContainer(
            retry: retries ? null : (_, _) => null,
            overrides: _overrides(
              active: [
                _investment('usd', 'USD'),
                _investment('open', 'USD', status: InvestmentStatus.open),
              ],
              activeFlows: [..._usdFlows('usd'), ..._usdFlows('open')],
              archived: [archived],
              archivedFlows: {'arch': _usdFlows('arch')},
              conversionService: entry.value,
            ),
          );
          addTearDown(container.dispose);
          // Every state each screen sees, including those during retries.
          final seen = <String, List<AsyncValue<Object?>>>{};
          void record(String name, ProviderListenable<AsyncValue<Object?>> p) {
            container.listen(
              p,
              (_, next) => seen.putIfAbsent(name, () => []).add(next),
              fireImmediately: true,
            );
          }

          record('basic stats map', activeInvestmentBasicStatsMapProvider);
          record('card stats', investmentBasicStatsProvider('usd'));
          record('XIRR map', activeInvestmentXirrResultMapProvider);
          record('detail stats', multiCurrencyInvestmentStatsProvider('usd'));
          record(
            'archived stats',
            multiCurrencyArchivedInvestmentStatsProvider('arch'),
          );
          // Overview hero, open and closed sections, and FIRE.
          record('global stats', multiCurrencyGlobalStatsProvider);
          record('open stats', multiCurrencyOpenStatsProvider);
          record('closed stats', multiCurrencyClosedStatsProvider);
          await _settle();

          expect(seen.keys, hasLength(8));
          // The Overview providers emit empty stats while the cash-flow
          // stream is still loading (A28 replaces that with a loading
          // state). Empty stats hold no amounts, so only stats with data
          // count as showing amounts for them.
          const emptyWhileLoading = {
            'global stats',
            'open stats',
            'closed stats',
          };
          for (final MapEntry(key: name, value: states) in seen.entries) {
            bool showsAmounts(AsyncValue<Object?> s) =>
                s.hasValue &&
                !(emptyWhileLoading.contains(name) &&
                    s.value is InvestmentStats &&
                    !(s.value! as InvestmentStats).hasData);
            expect(
              states.where(showsAmounts),
              isEmpty,
              reason: '$name must never show unconverted amounts: $states',
            );
            if (!retries) {
              expect(
                states.last.hasError,
                isTrue,
                reason: '$name must be in its error state: $states',
              );
            }
          }
        });
      }
    }
  });

  group('Overview analytics use converted amounts', () {
    test('type distribution and recently closed', () async {
      final container = ProviderContainer(
        overrides: _overrides(
          active: [
            _investment('usd', 'USD'),
            _investment('inr', 'INR', type: InvestmentType.fixedDeposit),
          ],
          activeFlows: [..._usdFlows('usd'), ..._inrFlows('inr')],
        ),
      );
      addTearDown(container.dispose);
      container.listen(investmentTypeDistributionProvider, (_, _) {});
      container.listen(recentlyClosedInvestmentsProvider, (_, _) {});
      await _settle();

      final distribution = container
          .read(investmentTypeDistributionProvider)
          .requireValue;
      expect(distribution.first.type, InvestmentType.stocks);
      expect(distribution.first.totalInvested, closeTo(83800, 0.005));
      expect(distribution.last.totalInvested, closeTo(50000, 0.005));

      final closed = container
          .read(recentlyClosedInvestmentsProvider)
          .requireValue;
      final usd = closed.singleWhere((c) => c.investment.id == 'usd');
      expect(usd.stats.netCashFlow, closeTo(_expectedNet, 0.005));
      expect(usd.stats.xirr, closeTo(_expectedXirr, 1e-6));
    });

    test('monthly trend and year-over-year', () async {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final flows = [
        // $500 out and $100 in this month, at 88.0 (dates from 2025 on).
        _flow('t1', 'usd', CashFlowType.invest, 500, 'USD', thisMonth),
        _flow('t2', 'usd', CashFlowType.income, 100, 'USD', thisMonth),
      ];
      final container = ProviderContainer(
        overrides: _overrides(
          active: [_investment('usd', 'USD', status: InvestmentStatus.open)],
          activeFlows: flows,
        ),
      );
      addTearDown(container.dispose);
      container.listen(monthlyCashFlowTrendProvider, (_, _) {});
      container.listen(yoyComparisonProvider, (_, _) {});
      await _settle();

      final trend = container.read(monthlyCashFlowTrendProvider).requireValue;
      expect(trend.last.outflows, closeTo(44000, 0.005));
      expect(trend.last.inflows, closeTo(8800, 0.005));

      final yoy = container.read(yoyComparisonProvider).requireValue;
      expect(yoy.thisYearInvested, closeTo(44000, 0.005));
      expect(yoy.thisYearReturned, closeTo(8800, 0.005));
    });
  });

  group('InvestmentCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      InvestmentEntity investment,
      List<Override> overrides,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            privacyModeProvider.overrideWith(_PrivacyOff.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InvestmentCard(
                investment: investment,
                isSelectionMode: false,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      // Streams, conversion and the XIRR isolate complete outside the fake
      // clock.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    String compactInr(double amount) {
      final container = ProviderContainer(
        overrides: [currencyCodeProvider.overrideWith((ref) => 'INR')],
      );
      addTearDown(container.dispose);
      return container.read(currencyFormatProvider).formatCompact(amount);
    }

    testWidgets('an active USD card shows the converted net', (tester) async {
      final investment = _investment('usd', 'USD');
      await pumpCard(
        tester,
        investment,
        _overrides(active: [investment], activeFlows: _usdFlows('usd')),
      );
      expect(find.text('+${compactInr(_expectedNet)}'), findsOneWidget);
      expect(find.text('+7.5% IRR'), findsOneWidget);
    });

    testWidgets('an archived USD card shows the converted net', (tester) async {
      final investment = _investment('arch', 'USD', archived: true);
      await pumpCard(
        tester,
        investment,
        _overrides(
          active: const [],
          activeFlows: const [],
          archived: [investment],
          archivedFlows: {'arch': _usdFlows('arch')},
        ),
      );
      expect(find.text('+${compactInr(_expectedNet)}'), findsOneWidget);
      expect(find.text('+7.5% IRR'), findsOneWidget);
    });
  });
}
