/// A flow that cannot be converted must be left out of a total, never summed
/// under the base-currency symbol.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_trend_analyzer.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// Converts USD at 83 and has no rate (live, dated or cached) for anything else.
class _OnlyUsdService extends MockCurrencyConversionService {
  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    if (requests.values.any((r) => r.from != 'USD')) {
      throw CurrencyConversionException('no rate');
    }
    return {for (final key in requests.keys) key: 83.0};
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => null;
}

CashFlowEntity _flow(
  String id,
  double amount,
  String currency, {
  CashFlowType type = CashFlowType.invest,
}) => CashFlowEntity(
  id: id,
  investmentId: 'inv',
  date: DateTime.now().subtract(const Duration(days: 2)),
  type: type,
  amount: amount,
  createdAt: DateTime(2026, 4, 1),
  currency: currency,
);

InvestmentEntity _investment() => InvestmentEntity(
  id: 'inv',
  name: 'Fund',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  startDate: DateTime(2026, 4, 1),
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  currency: 'INR',
);

CalculationEngine _engine(CurrencyConversionService? service) =>
    CalculationEngine()
      ..registerModule(CurrencyConverterModule(service))
      ..registerModule(FinancialCalculatorModule());

void main() {
  test('batchConvertToBase drops the flow whose rate is missing', () async {
    final out = await CurrencyConverterModule(_OnlyUsdService())
        .batchConvertToBase(
          cashFlows: [
            _flow('usd', 100, 'USD'),
            _flow('eur', 100, 'EUR'),
            _flow('inr', 500, 'INR'),
          ],
          baseCurrency: 'INR',
        );
    expect(out.map((c) => c.id).toSet(), {'usd', 'inr'});
    expect(out.every((c) => c.currency == 'INR'), isTrue);
    expect(out.firstWhere((c) => c.id == 'usd').amount, 8300);
  });

  test(
    'batchConvertToBase drops foreign flows when conversion is unavailable',
    () async {
      final out = await CurrencyConverterModule(null).batchConvertToBase(
        cashFlows: [_flow('usd', 100, 'USD'), _flow('inr', 500, 'INR')],
        baseCurrency: 'INR',
      );
      expect(out.map((c) => c.id), ['inr']);
    },
  );

  test('FY report totals leave out a flow with no rate', () async {
    final report = await FYReportService(_engine(_OnlyUsdService()))
        .generateReport(
          fyYear: 2026,
          allCashFlows: [
            CashFlowEntity(
              id: 'usd',
              investmentId: 'inv',
              date: DateTime(2026, 5, 1),
              type: CashFlowType.invest,
              amount: 100,
              createdAt: DateTime(2026, 5, 1),
              currency: 'USD',
            ),
            CashFlowEntity(
              id: 'eur',
              investmentId: 'inv',
              date: DateTime(2026, 5, 1),
              type: CashFlowType.invest,
              amount: 100,
              createdAt: DateTime(2026, 5, 1),
              currency: 'EUR',
            ),
          ],
          allInvestments: [_investment()],
          baseCurrency: 'INR',
        );
    expect(report.totalInvested, 8300);
  });

  test('income sources leave out a flow with no rate', () async {
    final report = await IncomeTrendAnalyzer().generateReport(
      investments: [_investment()],
      cashFlows: [
        _flow('usd', 100, 'USD', type: CashFlowType.income),
        _flow('eur', 100, 'EUR', type: CashFlowType.income),
      ],
      expectedCashFlows: [],
      engine: _engine(_OnlyUsdService()),
      baseCurrency: 'INR',
    );
    expect(report.totalIncome, 8300);
    expect(report.incomeSources.length, 1);
    expect(report.incomeSources.single.totalIncome, 8300);
  });

  test(
    'no insight calls income diversified when no source has a rate',
    () async {
      final report = await IncomeTrendAnalyzer().generateReport(
        investments: [_investment()],
        cashFlows: [_flow('eur', 100, 'EUR', type: CashFlowType.income)],
        expectedCashFlows: [],
        engine: _engine(_OnlyUsdService()),
        baseCurrency: 'INR',
      );
      expect(report.incomeSources, isEmpty);
      expect(
        report.insights.any((i) => i.contains('diversification')),
        isFalse,
      );
    },
  );
}
