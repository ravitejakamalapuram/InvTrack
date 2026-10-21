import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';
import 'package:inv_tracker/features/reports/data/services/interest_schedule_service.dart';

CashFlowEntity _cf(
  String id,
  String inv,
  double amount,
  DateTime date, {
  CashFlowType type = CashFlowType.income,
  String? notes = 'Interest',
}) => CashFlowEntity(
  id: id,
  investmentId: inv,
  amount: amount,
  date: date,
  type: type,
  notes: notes,
  currency: 'USD',
  createdAt: date,
);

InvestmentEntity _inv(String id, String name, {String? platform}) =>
    InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      platform: platform,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
      currency: 'USD',
    );

void main() {
  late CalculationEngine engine;
  late InterestScheduleService service;

  setUp(() {
    engine = CalculationEngine()
      ..registerModule(CurrencyConverterModule(null))
      ..registerModule(FinancialCalculatorModule());
    service = InterestScheduleService(engine);
  });

  final investments = [
    _inv('a', 'FD One', platform: 'HDFC Bank'),
    _inv('b', 'FD Two', platform: 'HDFC Bank'),
    _inv('c', 'Bond C'),
    _inv('d', 'Blank D', platform: ''),
  ];

  final flows = [
    _cf('1', 'a', 100, DateTime(2023, 4, 1)), // first day of FY, included
    _cf('2', 'b', 50, DateTime(2024, 3, 31, 23, 59)), // last day, included
    _cf('3', 'a', 25, DateTime(2023, 9, 10)),
    _cf('4', 'c', 70, DateTime(2023, 12, 5), notes: 'Quarterly interest'),
    _cf('5', 'd', 5, DateTime(2024, 1, 2), notes: 'INTEREST'),
    _cf('6', 'a', 999, DateTime(2023, 3, 31)), // before FY
    _cf('7', 'a', 888, DateTime(2024, 4, 1)), // next FY start, excluded
    _cf('8', 'a', 777, DateTime(2023, 6, 1), notes: 'Dividend'), // not interest
    _cf('9', 'a', 666, DateTime(2023, 6, 2), notes: 'Dividend interest'),
    _cf('10', 'a', 555, DateTime(2023, 6, 3), type: CashFlowType.returnFlow),
  ];

  test(
    'groups FY interest by payer with exact totals, counts and dates',
    () async {
      final s = await service.generate(
        fyYear: 2023,
        allCashFlows: flows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(s.fyLabel, '2023-24');
      expect(s.rows.map((r) => r.payer).toList(), [
        'Blank D',
        'Bond C',
        'HDFC Bank',
      ]);
      final hdfc = s.rows.firstWhere((r) => r.payer == 'HDFC Bank');
      expect(hdfc.totalInterest, 175.0);
      expect(hdfc.paymentCount, 3);
      expect(hdfc.firstPaymentDate, DateTime(2023, 4, 1));
      expect(hdfc.lastPaymentDate, DateTime(2024, 3, 31));
      final bond = s.rows.firstWhere((r) => r.payer == 'Bond C');
      expect(bond.totalInterest, 70.0);
      expect(bond.paymentCount, 1);
      expect(bond.firstPaymentDate, bond.lastPaymentDate);
      expect(s.grandTotal, 250.0);
    },
  );

  test('grand total equals the FY report interest income', () async {
    final s = await service.generate(
      fyYear: 2023,
      allCashFlows: flows,
      allInvestments: investments,
      baseCurrency: 'USD',
    );
    final report = await FYReportService(engine).generateReport(
      fyYear: 2023,
      // The return flow would add realised profit to the report; leave it out
      // so the report figure is interest from income flows only.
      allCashFlows: flows
          .where((f) => f.type != CashFlowType.returnFlow)
          .toList(),
      allInvestments: investments,
      baseCurrency: 'USD',
    );
    expect(s.grandTotal, report.interestIncome);
  });

  test('empty FY gives no rows and zero total', () async {
    final s = await service.generate(
      fyYear: 2020,
      allCashFlows: flows,
      allInvestments: investments,
      baseCurrency: 'USD',
    );
    expect(s.rows, isEmpty);
    expect(s.grandTotal, 0.0);
  });

  group('schedule edge cases', () {
    test(
      'interest for an unknown investment is grouped under a null payer',
      () async {
        final s = await service.generate(
          fyYear: 2023,
          allCashFlows: [
            _cf('1', 'ghost', 40, DateTime(2023, 5, 1)),
            _cf('2', 'ghost', 10, DateTime(2023, 8, 9)),
            _cf('3', 'a', 100, DateTime(2023, 6, 1)),
          ],
          allInvestments: investments,
          baseCurrency: 'USD',
        );
        expect(s.rows.map((r) => r.payer).toList(), ['HDFC Bank', null]);
        final ghost = s.rows.last;
        expect(ghost.totalInterest, 50.0);
        expect(ghost.paymentCount, 2);
        expect(ghost.firstPaymentDate, DateTime(2023, 5, 1));
        expect(ghost.lastPaymentDate, DateTime(2023, 8, 9));
        expect(s.grandTotal, 150.0);
      },
    );

    test(
      'a flow in a currency with no rate is left out of row and total',
      () async {
        final eur = CashFlowEntity(
          id: 'e',
          investmentId: 'a',
          amount: 900,
          date: DateTime(2023, 7, 1),
          type: CashFlowType.income,
          notes: 'Interest',
          currency: 'EUR',
          createdAt: DateTime(2023, 7, 1),
        );
        final s = await service.generate(
          fyYear: 2023,
          allCashFlows: [eur, _cf('1', 'a', 100, DateTime(2023, 6, 1))],
          allInvestments: investments,
          baseCurrency: 'USD',
        );
        expect(s.rows.single.totalInterest, 100.0);
        expect(s.rows.single.paymentCount, 1);
        expect(s.grandTotal, 100.0);
      },
    );
  });
}
