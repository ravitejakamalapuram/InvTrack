// A72 (#837): the projected maturity value compounds the principal (INVEST
// flows only), never fees. Invested, MOIC and XIRR keep counting fees.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Converts with fixed rates keyed 'FROM_TO'; no network.
class _FixedRateService implements CurrencyConversionService {
  _FixedRateService(this.rates);
  final Map<String, double> rates;

  double _rate(String from, String to) {
    if (from == to) return 1;
    final rate = rates['${from}_$to'];
    if (rate == null) throw CurrencyConversionException('No rate');
    return rate;
  }

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => amount * _rate(from, to);

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => _rate(from, to);

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {
    for (final entry in requests.entries)
      entry.key: _rate(entry.value.from, to),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CashFlowEntity _flow(
  String id,
  CashFlowType type,
  double amount, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: id,
  investmentId: 'fd-1',
  date: DateTime(2026, 1, 1),
  type: type,
  amount: amount,
  currency: currency,
  createdAt: DateTime(2026, 1, 1),
);

double? _projectedMaturity(double principal) =>
    InvestmentProjector.getProjectionSummary(
      principal: principal,
      annualRate: 7,
      tenureMonths: 36,
      compounding: CompoundingFrequency.quarterly,
      type: InvestmentType.fixedDeposit,
    )?.maturityValue;

void main() {
  final financial = FinancialCalculatorModule();

  test('principal is the INVEST sum; invested still includes the fee', () {
    final stats = financial.calculateStats([
      _flow('1', CashFlowType.invest, 100000),
      _flow('2', CashFlowType.fee, 500),
    ]);

    expect(stats.principal, 100000);
    expect(stats.totalInvested, 100500);
  });

  test('a Rs500 fee does not compound: Rs1,23,143.93, not Rs1,23,759.65', () {
    final withFee = financial.calculateStats([
      _flow('1', CashFlowType.invest, 100000),
      _flow('2', CashFlowType.fee, 500),
    ]);
    final withoutFee = financial.calculateStats([
      _flow('1', CashFlowType.invest, 100000),
    ]);

    // 100000 * 1.0175^12 = 1,23,143.93
    expect(_projectedMaturity(withFee.principal), closeTo(123143.93, 0.005));
    expect(_projectedMaturity(withoutFee.principal), closeTo(123143.93, 0.005));
  });

  test('principal is the converted INVEST sum for a USD investment', () async {
    final currency = CurrencyConverterModule(
      _FixedRateService({'USD_INR': 88.0}),
    );
    final converted = await currency.batchConvert(
      cashFlows: [
        _flow('1', CashFlowType.invest, 1000, currency: 'USD'),
        _flow('2', CashFlowType.fee, 10, currency: 'USD'),
      ],
      baseCurrency: 'INR',
      fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
    );

    final stats = financial.calculateStats(converted);

    expect(stats.principal, closeTo(88000.00, 0.005));
    expect(stats.totalInvested, closeTo(88880.00, 0.005));
  });

  test('income, returns and empty stats add nothing to principal', () {
    final stats = financial.calculateStats([
      _flow('1', CashFlowType.invest, 50000),
      _flow('2', CashFlowType.income, 1200),
      _flow('3', CashFlowType.returnFlow, 10000),
    ]);
    expect(stats.principal, 50000);
    expect(financial.calculateStats(const []).principal, 0);
  });
}
