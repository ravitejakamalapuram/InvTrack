import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';

void main() {
  group('FYReportService', () {
    late FYReportService service;
    const int fyYear = 2023; // FY 2023-24 (Apr 1, 2023 - Mar 31, 2024)

    setUp(() {
      final engine = CalculationEngine()
        ..registerModule(CurrencyConverterModule(null))
        ..registerModule(FinancialCalculatorModule());
      service = FYReportService(engine);
    });

    test('should calculate FY totals correctly', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2023, 5, 1), // Within FY
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 5, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          notes: 'Dividend',
          currency: 'USD',
          createdAt: DateTime(2023, 6, 1),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 11000,
          date: DateTime(2024, 3, 15),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 3, 15),
        ),
        CashFlowEntity(
          id: '4',
          investmentId: 'inv1',
          amount: 100,
          date: DateTime(2023, 7, 1),
          type: CashFlowType.fee,
          currency: 'USD',
          createdAt: DateTime(2023, 7, 1),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 5, 1),
          createdAt: DateTime(2023, 5, 1),
          updatedAt: DateTime(2023, 5, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 10000.0);
      expect(report.totalIncome, 500.0);
      expect(report.totalReturns, 11000.0);
      expect(report.totalFees, 100.0);
      expect(report.netCashFlow, 1400.0); // (500 + 11000) - (10000 + 100)
      expect(report.fyLabel, '2023-24');
    });

    test('should filter out cashflows outside FY period', () async {
      final cashFlows = [
        // Before FY start (Mar 30, 2023 - should be excluded)
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2023, 3, 30),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 3, 30),
        ),
        // Within FY (May 1, 2023)
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 2000,
          date: DateTime(2023, 5, 1),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 5, 1),
        ),
        // After FY end (Apr 2, 2024 - should be excluded)
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 3000,
          date: DateTime(2024, 4, 2),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 4, 2),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 2000.0); // Only May 1 transaction included
    });

    test('should categorize dividend and interest income', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          notes: 'Dividend payment',
          currency: 'USD',
          createdAt: DateTime(2023, 6, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv2',
          amount: 300,
          date: DateTime(2023, 7, 1),
          type: CashFlowType.income,
          notes: 'Interest earned',
          currency: 'USD',
          createdAt: DateTime(2023, 7, 1),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stock A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'FD B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalIncome, 800.0);
      expect(report.dividendIncome, 500.0);
      expect(report.interestIncome, 300.0);
    });

    test(
      'open holding awaiting a value is not ranked as a top performer',
      () async {
        InvestmentEntity inv(String id) => InvestmentEntity(
          id: id,
          name: id,
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 5, 1),
          createdAt: DateTime(2023, 5, 1),
          updatedAt: DateTime(2023, 5, 1),
          currency: 'USD',
        );
        CashFlowEntity cf(
          String id,
          String i,
          double a,
          CashFlowType t,
          DateTime d,
        ) => CashFlowEntity(
          id: id,
          investmentId: i,
          amount: a,
          date: d,
          type: t,
          currency: 'USD',
          createdAt: d,
        );

        final report = await service.generateReport(
          fyYear: fyYear,
          allCashFlows: [
            cf('1', 'paid', 1000, CashFlowType.invest, DateTime(2023, 5, 1)),
            cf(
              '2',
              'paid',
              1200,
              CashFlowType.returnFlow,
              DateTime(2024, 3, 1),
            ),
            cf(
              '3',
              'awaiting',
              1000,
              CashFlowType.invest,
              DateTime(2023, 5, 1),
            ),
            cf(
              '4',
              'awaiting',
              900,
              CashFlowType.returnFlow,
              DateTime(2024, 3, 1),
            ),
          ],
          allInvestments: [inv('paid'), inv('awaiting')],
          baseCurrency: 'USD',
        );

        expect(report.topPerformersByReturns.map((p) => p.investment.id), [
          'paid',
        ]);
        expect(report.topPerformersByXIRR.map((p) => p.investment.id), [
          'paid',
        ]);
      },
    );

    test('should handle empty data', () async {
      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: [],
        allInvestments: [],
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 0.0);
      expect(report.totalIncome, 0.0);
      expect(report.totalReturns, 0.0);
      expect(report.totalFees, 0.0);
      expect(report.netCashFlow, 0.0);
      expect(report.dividendIncome, 0.0);
      expect(report.interestIncome, 0.0);
    });

    test('should calculate correct FY start and end dates', () async {
      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: [],
        allInvestments: [],
        baseCurrency: 'USD',
      );

      expect(report.fyStart.year, 2023);
      expect(report.fyStart.month, 4);
      expect(report.fyStart.day, 1);

      expect(report.fyEnd.year, 2024);
      expect(report.fyEnd.month, 3);
      expect(report.fyEnd.day, 31);
    });

    test('should generate monthly breakdown with 12 months', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2023, 4, 15),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 4, 15),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 2000,
          date: DateTime(2023, 12, 20),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 20),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.monthlyBreakdown.length, 12); // All 12 months of FY
    });
  });

  // A60 (#800) slice 1: tax-head classification, half-open FY windows and
  // FY XIRR with opening and closing values.
  group('FYReportService A60 correctness', () {
    late FYReportService service;

    setUp(() {
      final engine = CalculationEngine()
        ..registerModule(CurrencyConverterModule(null))
        ..registerModule(FinancialCalculatorModule());
      service = FYReportService(engine);
    });

    CashFlowEntity flow(
      String id,
      String investmentId,
      double amount,
      CashFlowType type,
      DateTime date,
    ) => CashFlowEntity(
      id: id,
      investmentId: investmentId,
      amount: amount,
      date: date,
      type: type,
      currency: 'INR',
      createdAt: date,
    );

    InvestmentEntity investment(
      String id,
      DateTime start, {
      DateTime? closedAt,
    }) => InvestmentEntity(
      id: id,
      name: id,
      type: InvestmentType.fixedDeposit,
      status: closedAt == null
          ? InvestmentStatus.open
          : InvestmentStatus.closed,
      closedAt: closedAt,
      startDate: start,
      createdAt: start,
      updatedAt: start,
      currency: 'INR',
    );

    Future<FYReport> report(
      int fyYear,
      List<CashFlowEntity> flows,
      List<InvestmentEntity> investments, {
      Map<String, double>? openingValues,
      Map<String, double>? closingValues,
    }) => service.generateReport(
      fyYear: fyYear,
      allCashFlows: flows,
      allInvestments: investments,
      baseCurrency: 'INR',
      openingValues: openingValues,
      closingValues: closingValues,
    );

    test('a Rs 5L FD maturing at Rs 5.4L is Rs 40,000 interest and no '
        'capital gains', () async {
      final r = await report(
        2025,
        [
          flow('1', 'fd', 500000, CashFlowType.invest, DateTime(2025, 5, 1)),
          flow(
            '2',
            'fd',
            540000,
            CashFlowType.returnFlow,
            DateTime(2026, 3, 15),
          ),
        ],
        [investment('fd', DateTime(2025, 5, 1))],
      );

      expect(r.shortTermCapitalGains, 0.0);
      expect(r.longTermCapitalGains, 0.0);
      expect(r.interestIncome, 40000.0);
    });

    test('a loss on maturity is not income and not a gain', () async {
      final r = await report(
        2025,
        [
          flow('1', 'fd', 500000, CashFlowType.invest, DateTime(2025, 5, 1)),
          flow(
            '2',
            'fd',
            480000,
            CashFlowType.returnFlow,
            DateTime(2026, 3, 15),
          ),
        ],
        [investment('fd', DateTime(2025, 5, 1))],
      );

      expect(r.totalCapitalGains, 0.0);
      expect(r.interestIncome, 0.0);
    });

    test('profit realised in an earlier FY is not reported again', () async {
      final r = await report(
        2026,
        [
          flow('1', 'fd', 500000, CashFlowType.invest, DateTime(2025, 5, 1)),
          flow(
            '2',
            'fd',
            540000,
            CashFlowType.returnFlow,
            DateTime(2026, 3, 15),
          ),
        ],
        [investment('fd', DateTime(2025, 5, 1))],
      );

      expect(r.interestIncome, 0.0);
    });

    test('a flow at 2025-04-01 00:00 counts in FY 2025-26 only', () async {
      final flows = [
        flow('1', 'a', 100, CashFlowType.invest, DateTime(2025, 3, 31)),
        flow('2', 'a', 200, CashFlowType.invest, DateTime(2025, 4, 1)),
        flow('3', 'a', 400, CashFlowType.invest, DateTime(2026, 3, 31, 23, 59)),
        flow('4', 'a', 800, CashFlowType.invest, DateTime(2026, 4, 1)),
      ];
      final investments = [investment('a', DateTime(2025, 1, 1))];

      final fy2024 = await report(2024, flows, investments);
      final fy2025 = await report(2025, flows, investments);
      final fy2026 = await report(2026, flows, investments);

      expect(fy2024.totalInvested, 100.0);
      expect(fy2025.totalInvested, 600.0);
      expect(fy2026.totalInvested, 800.0);
    });

    test(
      'portfolio value at the start of an FY excludes a 1 April flow',
      () async {
        final r = await report(
          2025,
          [flow('1', 'a', 1000, CashFlowType.invest, DateTime(2025, 4, 1))],
          [investment('a', DateTime(2025, 4, 1))],
        );

        expect(r.portfolioValueAtStart, 0.0);
        expect(r.portfolioValueAtEnd, 1000.0);
      },
    );

    test('FY XIRR is undefined when a holding crosses the FY start without '
        'an opening value', () async {
      final r = await report(
        2025,
        [flow('1', 'h', 100000, CashFlowType.invest, DateTime(2024, 6, 1))],
        [investment('h', DateTime(2024, 6, 1))],
        closingValues: {'h': 110000},
      );

      expect(r.xirr, isNull);
    });

    test('FY XIRR is undefined when a holding crosses the FY end without a '
        'closing value', () async {
      final r = await report(
        2025,
        [flow('1', 'h', 100000, CashFlowType.invest, DateTime(2025, 6, 1))],
        [investment('h', DateTime(2025, 6, 1))],
      );

      expect(r.xirr, isNull);
    });

    test('FY XIRR uses the opening value as an outflow and the closing value '
        'as an inflow', () async {
      final r = await report(
        2025,
        [flow('1', 'h', 100000, CashFlowType.invest, DateTime(2024, 6, 1))],
        [investment('h', DateTime(2024, 6, 1))],
        openingValues: {'h': 100000},
        closingValues: {'h': 110000},
      );

      // 1 Apr 2025 to 1 Apr 2026 is exactly 365 days: 100000 -> 110000.
      expect(r.xirr, closeTo(0.10, 1e-6));
    });

    test('FY XIRR of an FD opened and matured inside the FY needs no '
        'boundary values', () async {
      final r = await report(
        2025,
        [
          flow('1', 'fd', 500000, CashFlowType.invest, DateTime(2025, 4, 1)),
          flow(
            '2',
            'fd',
            540000,
            CashFlowType.returnFlow,
            DateTime(2026, 3, 31),
          ),
        ],
        [
          investment(
            'fd',
            DateTime(2025, 4, 1),
            closedAt: DateTime(2026, 3, 31),
          ),
        ],
      );

      // 364 days.
      expect(r.xirr, closeTo(math.pow(1.08, 365 / 364) - 1, 1e-6));
    });
    test(
      'a loss-making FD that matures inside the FY still has an XIRR',
      () async {
        final r = await report(
          2025,
          [
            flow('1', 'fd', 500000, CashFlowType.invest, DateTime(2025, 5, 1)),
            flow(
              '2',
              'fd',
              480000,
              CashFlowType.returnFlow,
              DateTime(2026, 3, 15),
            ),
          ],
          [
            investment(
              'fd',
              DateTime(2025, 5, 1),
              closedAt: DateTime(2026, 3, 15),
            ),
          ],
        );

        expect(r.xirr, isNotNull);
        expect(r.xirr! < 0, isTrue);
      },
    );

    test('an open holding with a profitable partial exit needs boundary '
        'values', () async {
      final r = await report(
        2025,
        [
          flow('1', 'h', 1000, CashFlowType.invest, DateTime(2025, 5, 1)),
          flow('2', 'h', 1200, CashFlowType.returnFlow, DateTime(2025, 9, 1)),
        ],
        [investment('h', DateTime(2025, 5, 1))],
      );

      expect(r.xirr, isNull);
    });

    test('a top-up after a realised profit does not report it twice', () async {
      final flows = [
        flow('1', 'p', 100, CashFlowType.invest, DateTime(2024, 5, 1)),
        flow('2', 'p', 120, CashFlowType.returnFlow, DateTime(2024, 9, 1)),
        flow('3', 'p', 100, CashFlowType.invest, DateTime(2025, 5, 1)),
        flow('4', 'p', 100, CashFlowType.returnFlow, DateTime(2026, 5, 1)),
      ];
      final investments = [investment('p', DateTime(2024, 5, 1))];

      expect((await report(2024, flows, investments)).interestIncome, 20.0);
      expect((await report(2025, flows, investments)).interestIncome, 0.0);
      expect((await report(2026, flows, investments)).interestIncome, 0.0);
    });
  });

  // A60 (#800) slice 2: opening and closing values come from the latest
  // valuation snapshot before each 1 April.
  group('FYReportService valuationsAtFYEdges', () {
    late FYReportService service;

    setUp(() {
      final engine = CalculationEngine()
        ..registerModule(
          CurrencyConverterModule(MockCurrencyConversionService()),
        )
        ..registerModule(FinancialCalculatorModule());
      service = FYReportService(engine);
    });

    InvestmentEntity holding(String id, {String currency = 'INR'}) =>
        InvestmentEntity(
          id: id,
          name: id,
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2024, 6, 1),
          createdAt: DateTime(2024, 6, 1),
          updatedAt: DateTime(2024, 6, 1),
          currency: currency,
        );

    InvestmentValuationSnapshot snap(
      String id,
      String investmentId,
      double amount,
      DateTime date, {
      ValuationKind kind = ValuationKind.carryingValue,
      String currency = 'INR',
      DateTime? deletedAt,
    }) => InvestmentValuationSnapshot(
      id: id,
      investmentId: investmentId,
      amount: amount,
      currency: currency,
      effectiveDate: date,
      kind: kind,
      provenance: ValuationProvenance.manual,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      deletedAt: deletedAt,
    );

    CashFlowEntity invest(String id, String inv, double amt, String cur) =>
        CashFlowEntity(
          id: id,
          investmentId: inv,
          amount: amt,
          date: DateTime(2024, 6, 1),
          type: CashFlowType.invest,
          currency: cur,
          createdAt: DateTime(2024, 6, 1),
        );

    Future<FYReport> reportFor(
      List<InvestmentEntity> investments,
      List<CashFlowEntity> flows,
      List<InvestmentValuationSnapshot> snapshots,
    ) async {
      final edges = await service.valuationsAtFYEdges(
        fyYear: 2025,
        investments: investments,
        snapshots: snapshots,
        baseCurrency: 'INR',
      );
      return service.generateReport(
        fyYear: 2025,
        allCashFlows: flows,
        allInvestments: investments,
        baseCurrency: 'INR',
        openingValues: edges.opening,
        closingValues: edges.closing,
      );
    }

    test('an FD crossing both edges takes the snapshots before each 1 April; '
        'a snapshot dated on the edge is ignored', () async {
      final snaps = [
        snap('a', 'fd', 500000, DateTime(2024, 6, 1)),
        snap('b', 'fd', 530000, DateTime(2025, 3, 31)),
        snap('c', 'fd', 531000, DateTime(2025, 4, 1)),
        snap('d', 'fd', 572400, DateTime(2026, 3, 31)),
        snap('e', 'fd', 580000, DateTime(2026, 4, 1)),
      ];
      final edges = await service.valuationsAtFYEdges(
        fyYear: 2025,
        investments: [holding('fd')],
        snapshots: snaps,
        baseCurrency: 'INR',
      );
      expect(edges.opening, {'fd': 530000.0});
      expect(edges.closing, {'fd': 572400.0});

      final r = await reportFor(
        [holding('fd')],
        [invest('1', 'fd', 500000, 'INR')],
        snaps,
      );
      // 572400 / 530000 = 1.08 over exactly 365 days.
      expect(r.xirr, closeTo(0.08, 1e-6));
    });

    test(
      'a market value snapshot is preferred over a later carrying value, '
      'and the latest of any kind is used when there is no market value',
      () async {
        final edges = await service.valuationsAtFYEdges(
          fyYear: 2025,
          investments: [holding('m'), holding('c')],
          snapshots: [
            snap(
              '1',
              'm',
              90000,
              DateTime(2025, 1, 1),
              kind: ValuationKind.marketValue,
            ),
            snap(
              '2',
              'm',
              95000,
              DateTime(2025, 1, 15),
              kind: ValuationKind.marketValue,
            ),
            snap('3', 'm', 99999, DateTime(2025, 3, 20)),
            snap(
              '4',
              'm',
              121000,
              DateTime(2026, 3, 15),
              kind: ValuationKind.marketValue,
            ),
            snap('5', 'c', 70000, DateTime(2025, 2, 1)),
            snap(
              '6',
              'c',
              72000,
              DateTime(2025, 3, 1),
              kind: ValuationKind.principalOutstanding,
            ),
            snap('7', 'c', 80000, DateTime(2026, 3, 1)),
          ],
          baseCurrency: 'INR',
        );
        expect(edges.opening, {'m': 95000.0, 'c': 72000.0});
        expect(edges.closing, {'m': 121000.0, 'c': 80000.0});
      },
    );

    test(
      'a USD holding is converted to the base currency (1 USD = 83 INR)',
      () async {
        final usd = holding('us', currency: 'USD');
        final snaps = [
          snap('1', 'us', 1000, DateTime(2025, 3, 31), currency: 'USD'),
          snap('2', 'us', 1100, DateTime(2026, 3, 31), currency: 'USD'),
        ];
        final edges = await service.valuationsAtFYEdges(
          fyYear: 2025,
          investments: [usd],
          snapshots: snaps,
          baseCurrency: 'INR',
        );
        expect(edges.opening, {'us': 83000.0});
        expect(edges.closing, {'us': 91300.0});

        final r = await reportFor(
          [usd],
          [invest('1', 'us', 1000, 'USD')],
          snaps,
        );
        expect(r.xirr, closeTo(0.10, 1e-6));
      },
    );

    test(
      'a holding with no snapshot gets no value and the XIRR stays null',
      () async {
        final snaps = [
          snap('1', 'a', 100000, DateTime(2025, 3, 31)),
          snap('2', 'a', 110000, DateTime(2026, 3, 31)),
        ];
        final both = [holding('a'), holding('b')];
        final edges = await service.valuationsAtFYEdges(
          fyYear: 2025,
          investments: both,
          snapshots: snaps,
          baseCurrency: 'INR',
        );
        expect(edges.opening, {'a': 100000.0});
        expect(edges.closing, {'a': 110000.0});

        final r = await reportFor(both, [
          invest('1', 'a', 100000, 'INR'),
          invest('2', 'b', 50000, 'INR'),
        ], snaps);
        expect(r.xirr, isNull);
      },
    );

    test('a deleted snapshot, one in another currency, and one whose rate is '
        'unknown are all left out', () async {
      final edges = await service.valuationsAtFYEdges(
        fyYear: 2025,
        investments: [
          holding('del'),
          holding('cur'),
          holding('xyz', currency: 'XYZ'),
        ],
        snapshots: [
          snap(
            '1',
            'del',
            100,
            DateTime(2025, 3, 1),
            deletedAt: DateTime(2025, 3, 2),
          ),
          snap('2', 'cur', 100, DateTime(2025, 3, 1), currency: 'USD'),
          snap('3', 'xyz', 100, DateTime(2025, 3, 1), currency: 'XYZ'),
        ],
        baseCurrency: 'INR',
      );
      expect(edges.opening, isEmpty);
      expect(edges.closing, isEmpty);
    });

    test(
      'a zero conversion rate counts as impossible and omits the holding',
      () async {
        final zeroRate = FYReportService(
          CalculationEngine()
            ..registerModule(CurrencyConverterModule(_ZeroUsdService()))
            ..registerModule(FinancialCalculatorModule()),
        );
        final edges = await zeroRate.valuationsAtFYEdges(
          fyYear: 2025,
          investments: [holding('us', currency: 'USD')],
          snapshots: [
            snap('1', 'us', 1000, DateTime(2025, 3, 31), currency: 'USD'),
          ],
          baseCurrency: 'INR',
        );
        expect(edges.opening, isEmpty);
      },
    );

    test('a zero-valued snapshot with a zero rate is omitted too', () async {
      final zeroRate = FYReportService(
        CalculationEngine()
          ..registerModule(CurrencyConverterModule(_ZeroUsdService()))
          ..registerModule(FinancialCalculatorModule()),
      );
      final edges = await zeroRate.valuationsAtFYEdges(
        fyYear: 2025,
        investments: [holding('us', currency: 'USD')],
        snapshots: [snap('1', 'us', 0, DateTime(2025, 3, 31), currency: 'USD')],
        baseCurrency: 'INR',
      );
      expect(edges.opening, isEmpty);
    });

    test('fyReportProvider stays loading while snapshots load and surfaces '
        'a snapshot error', () async {
      ProviderContainer make(AsyncValue<List<InvestmentValuationSnapshot>> v) {
        final c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            activeInvestmentsProvider.overrideWithValue(
              AsyncData([holding('fd')]),
            ),
            validCashFlowsProvider.overrideWithValue(const AsyncData([])),
            currencyCodeProvider.overrideWithValue('INR'),
            validValuationSnapshotsProvider.overrideWithValue(v),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      final loading = make(const AsyncLoading());
      loading.listen(fyReportProvider(2025), (_, _) {});
      await expectLater(
        loading
            .read(fyReportProvider(2025).future)
            .timeout(const Duration(milliseconds: 200)),
        throwsA(isA<TimeoutException>()),
      );

      final failing = make(AsyncError('boom', StackTrace.empty));
      failing.listen(fyReportProvider(2025), (_, _) {});
      await expectLater(
        failing.read(fyReportProvider(2025).future),
        throwsA('boom'),
      );
    });

    test('fyReportProvider feeds snapshot values into the FY XIRR', () async {
      final fd = holding('fd');
      final container = ProviderContainer(
        overrides: [
          activeInvestmentsProvider.overrideWithValue(AsyncData([fd])),
          validCashFlowsProvider.overrideWithValue(
            AsyncData([invest('1', 'fd', 500000, 'INR')]),
          ),
          currencyCodeProvider.overrideWithValue('INR'),
          validValuationSnapshotsProvider.overrideWithValue(
            AsyncData([
              snap('b', 'fd', 530000, DateTime(2025, 3, 31)),
              snap('d', 'fd', 572400, DateTime(2026, 3, 31)),
            ]),
          ),
          calculationEngineProvider.overrideWithValue(
            CalculationEngine()
              ..registerModule(CurrencyConverterModule(null))
              ..registerModule(FinancialCalculatorModule()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final r = await container.read(fyReportProvider(2025).future);
      expect(r.xirr, closeTo(0.08, 1e-6));
    });
  });
}

class _ZeroUsdService extends MockCurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => from == to ? amount : 0.0;
}
