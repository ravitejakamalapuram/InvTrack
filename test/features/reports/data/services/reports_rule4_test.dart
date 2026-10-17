// Money rule 4 in the reports (#981): an open investment with no current
// value never gets an invented value, return % or XIRR; one that has returned
// its cost keeps its cash-only figures, flagged "so far".
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';
import 'package:inv_tracker/features/reports/data/services/performance_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/performance_report.dart';

InvestmentEntity _inv(String id, InvestmentStatus status) => InvestmentEntity(
  id: id,
  name: id,
  type: InvestmentType.p2pLending,
  status: status,
  startDate: DateTime(2023, 5, 1),
  createdAt: DateTime(2023, 5, 1),
  updatedAt: DateTime(2023, 5, 1),
  currency: 'INR',
);

CashFlowEntity _cf(
  String inv,
  double amount,
  DateTime date,
  CashFlowType type,
) => CashFlowEntity(
  id: '$inv-${date.millisecondsSinceEpoch}-${type.name}',
  investmentId: inv,
  amount: amount,
  date: date,
  type: type,
  currency: 'INR',
  createdAt: date,
);

// 10,000 in on 1 May 2023, [returned] back on 1 Feb 2024 (inside FY 2023-24).
List<CashFlowEntity> _flows(String inv, double returned) => [
  _cf(inv, 10000, DateTime(2023, 5, 1), CashFlowType.invest),
  _cf(inv, returned, DateTime(2024, 2, 1), CashFlowType.returnFlow),
];

void main() {
  group('PerformanceReportService rule 4', () {
    final service = PerformanceReportService();

    InvestmentPerformance perf(InvestmentStatus status, double returned) =>
        service
            .generateReport(
              allInvestments: [_inv('a', status)],
              allCashFlows: _flows('a', returned),
            )
            .allPerformances
            .single;

    test('open, no value, less back than in: no value, XIRR or return %', () {
      final p = perf(InvestmentStatus.open, 4000);
      expect(p.currentValue, isNull);
      expect(p.xirr, isNull);
      expect(p.percentageReturn, isNull);
      expect(p.returnsAreSoFar, isFalse);
    });

    test('open, no value, cost paid back: cash-only figures, so far', () {
      final p = perf(InvestmentStatus.open, 12000);
      expect(p.currentValue, isNull);
      expect(p.percentageReturn, closeTo(20.0, 1e-6));
      expect(p.xirr, isNotNull);
      expect(p.returnsAreSoFar, isTrue);
    });

    test('closed: unchanged figures, nothing held', () {
      final p = perf(InvestmentStatus.closed, 4000);
      expect(p.currentValue, 0);
      expect(p.percentageReturn, closeTo(-60.0, 1e-6));
      expect(p.xirr, isNotNull);
      expect(p.returnsAreSoFar, isFalse);
    });

    test('an investment awaiting a value is not ranked or a milestone', () {
      final report = service.generateReport(
        allInvestments: [_inv('a', InvestmentStatus.open)],
        allCashFlows: _flows('a', 4000),
      );
      expect(report.topPerformers, isEmpty);
      expect(report.averageXIRR, isNull);
      expect(report.recentMilestones, isEmpty);
    });
  });

  group('FYReportService rule 4', () {
    late FYReportService service;
    setUp(() {
      service = FYReportService(
        CalculationEngine()
          ..registerModule(CurrencyConverterModule(null))
          ..registerModule(FinancialCalculatorModule()),
      );
    });

    test('open investments awaiting a value are not ranked', () async {
      final report = await service.generateReport(
        fyYear: 2023,
        allInvestments: [
          _inv('awaiting', InvestmentStatus.open),
          _inv('paidBack', InvestmentStatus.open),
          _inv('closed', InvestmentStatus.closed),
        ],
        allCashFlows: [
          ..._flows('awaiting', 4000),
          ..._flows('paidBack', 12000),
          ..._flows('closed', 4000),
        ],
        baseCurrency: 'INR',
      );
      expect([
        for (final p in report.topPerformersByReturns) p.investment.id,
      ], unorderedEquals(['paidBack', 'closed']));
      expect([
        for (final p in report.topPerformersByXIRR) p.investment.id,
      ], unorderedEquals(['paidBack', 'closed']));
    });

    test('so-far flag: set for a paid-back open one, not for closed', () async {
      final report = await service.generateReport(
        fyYear: 2023,
        allInvestments: [
          _inv('paidBack', InvestmentStatus.open),
          _inv('closed', InvestmentStatus.closed),
        ],
        allCashFlows: [
          ..._flows('paidBack', 12000),
          ..._flows('closed', 12000),
        ],
        baseCurrency: 'INR',
      );
      final byId = {
        for (final p in report.topPerformersByReturns) p.investment.id: p,
      };
      expect(byId['paidBack']!.isSoFar, isTrue);
      expect(byId['closed']!.isSoFar, isFalse);
      expect(byId['paidBack']!.percentageGain, closeTo(20.0, 1e-6));
    });
  });
}
