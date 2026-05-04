/// Unit tests for PerformanceReportService
///
/// Tests the performance report service, focusing on:
/// - Bottom performers ordering fix (bug fix: bottomPerformers now in descending XIRR order)
/// - Top performers ordering and count limit
/// - Average and median XIRR calculation
/// - Profitable vs loss-making count
/// - Empty data handling
/// - Milestone detection
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/performance_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/performance_report.dart';

void main() {
  late PerformanceReportService service;

  // Helper to create an investment entity with minimal required fields
  InvestmentEntity makeInvestment({
    required String id,
    String? name,
    InvestmentType type = InvestmentType.fixedDeposit,
    InvestmentStatus status = InvestmentStatus.open,
  }) {
    return InvestmentEntity(
      id: id,
      name: name ?? 'Investment $id',
      type: type,
      status: status,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );
  }

  // Helper to create a standard invest + return pair for a given investment
  // Returns (cashFlows: [...]) where the XIRR will approximate returnAmount/investAmount - 1 per year
  List<CashFlowEntity> makeCashFlows({
    required String investmentId,
    required double investAmount,
    required double returnAmount,
    DateTime? investDate,
    DateTime? returnDate,
  }) {
    final start = investDate ?? DateTime(2023, 1, 1);
    final end = returnDate ?? DateTime(2024, 1, 1); // 1 year later
    return [
      CashFlowEntity(
        id: '${investmentId}_invest',
        investmentId: investmentId,
        date: start,
        type: CashFlowType.invest,
        amount: investAmount,
        createdAt: start,
      ),
      CashFlowEntity(
        id: '${investmentId}_return',
        investmentId: investmentId,
        date: end,
        type: CashFlowType.returnFlow,
        amount: returnAmount,
        createdAt: end,
      ),
    ];
  }

  setUp(() {
    service = PerformanceReportService();
  });

  group('PerformanceReportService', () {
    group('generateReport - empty data', () {
      test('returns empty report for no investments', () {
        final report = service.generateReport(
          allInvestments: [],
          allCashFlows: [],
        );

        expect(report.topPerformers, isEmpty);
        expect(report.bottomPerformers, isEmpty);
        expect(report.allPerformances, isEmpty);
        expect(report.averageXIRR, 0.0);
        expect(report.medianXIRR, 0.0);
        expect(report.totalInvestments, 0);
        expect(report.profitableCount, 0);
        expect(report.lossCount, 0);
        expect(report.recentMilestones, isEmpty);
      });

      test('skips investments with no cash flows', () {
        final investments = [makeInvestment(id: 'inv1')];
        // No cash flows for inv1

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: [],
        );

        expect(report.totalInvestments, 0); // Skipped because no cash flows
        expect(report.allPerformances, isEmpty);
      });
    });

    group('generateReport - topPerformers', () {
      test('returns top performers sorted by XIRR descending', () {
        final investments = [
          makeInvestment(id: 'inv1', name: 'Moderate'),
          makeInvestment(id: 'inv2', name: 'High'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000), // ~10% XIRR
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 14000), // ~40% XIRR
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.topPerformers.length, 2);
        // First performer should have higher XIRR than second
        expect(
          report.topPerformers[0].xirr,
          greaterThan(report.topPerformers[1].xirr),
        );
        expect(report.topPerformers[0].investment.name, 'High');
      });

      test('limits top performers to 5 even when more investments exist', () {
        // Create 7 investments with different returns
        final investments = List.generate(
          7,
          (i) => makeInvestment(id: 'inv$i', name: 'Investment $i'),
        );
        final cashFlows = <CashFlowEntity>[];
        for (int i = 0; i < 7; i++) {
          cashFlows.addAll(
            makeCashFlows(
              investmentId: 'inv$i',
              investAmount: 10000,
              returnAmount: 10000.0 + (i + 1) * 1000, // Different returns
            ),
          );
        }

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.topPerformers.length, 5);
        expect(report.allPerformances.length, 7);
      });

      test('includes all performers when fewer than 5', () {
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
          makeInvestment(id: 'inv3'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.topPerformers.length, 3);
      });
    });

    group('generateReport - bottomPerformers (bug fix regression)', () {
      // This group tests the critical bug fix:
      // OLD: sortedByXIRR.reversed.take(5).toList()   -> ascending order (worst first)
      // NEW: sortedByXIRR.reversed.take(5).toList().reversed.toList() -> descending order

      test('bottomPerformers are in descending XIRR order after fix', () {
        // Create 6 investments with clearly different XIRR values
        final investments = [
          makeInvestment(id: 'inv1', name: 'Best'),
          makeInvestment(id: 'inv2', name: 'Second'),
          makeInvestment(id: 'inv3', name: 'Third'),
          makeInvestment(id: 'inv4', name: 'Fourth'),
          makeInvestment(id: 'inv5', name: 'Fifth'),
          makeInvestment(id: 'inv6', name: 'Worst'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 16000), // ~60%
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 14000), // ~40%
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000), // ~30%
          ...makeCashFlows(investmentId: 'inv4', investAmount: 10000, returnAmount: 12000), // ~20%
          ...makeCashFlows(investmentId: 'inv5', investAmount: 10000, returnAmount: 11000), // ~10%
          ...makeCashFlows(investmentId: 'inv6', investAmount: 10000, returnAmount: 9000),  // ~-10%
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // bottomPerformers should contain the 5 lowest XIRR investments
        expect(report.bottomPerformers.length, 5);

        // After the fix: bottomPerformers should be in DESCENDING order (highest XIRR of the worst 5 first)
        // inv2 (40%) > inv3 (30%) > inv4 (20%) > inv5 (10%) > inv6 (-10%)
        final xirrValues = report.bottomPerformers.map((p) => p.xirr).toList();
        for (int i = 0; i < xirrValues.length - 1; i++) {
          expect(
            xirrValues[i],
            greaterThanOrEqualTo(xirrValues[i + 1]),
            reason:
                'bottomPerformers[$i].xirr (${xirrValues[i]}) should be >= '
                'bottomPerformers[${i + 1}].xirr (${xirrValues[i + 1]}) — '
                'bottom performers must be in descending XIRR order after the bug fix',
          );
        }
      });

      test('bottomPerformers does not include the top performer', () {
        final investments = [
          makeInvestment(id: 'inv1', name: 'Best'),
          makeInvestment(id: 'inv2', name: 'Second'),
          makeInvestment(id: 'inv3', name: 'Third'),
          makeInvestment(id: 'inv4', name: 'Fourth'),
          makeInvestment(id: 'inv5', name: 'Fifth'),
          makeInvestment(id: 'inv6', name: 'Worst'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 16000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 14000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
          ...makeCashFlows(investmentId: 'inv4', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv5', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv6', investAmount: 10000, returnAmount: 9000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // The best investment (inv1) should NOT be in bottom performers
        final bottomIds = report.bottomPerformers.map((p) => p.investment.id).toSet();
        expect(bottomIds, isNot(contains('inv1')));
      });

      test('bottomPerformers includes the absolute worst performer', () {
        final investments = [
          makeInvestment(id: 'inv1', name: 'Best'),
          makeInvestment(id: 'inv2', name: 'Second'),
          makeInvestment(id: 'inv3', name: 'Third'),
          makeInvestment(id: 'inv4', name: 'Fourth'),
          makeInvestment(id: 'inv5', name: 'Fifth'),
          makeInvestment(id: 'inv6', name: 'Worst'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 16000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 14000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
          ...makeCashFlows(investmentId: 'inv4', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv5', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv6', investAmount: 10000, returnAmount: 9000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // The worst investment (inv6, negative XIRR) MUST be in bottom performers
        final bottomIds = report.bottomPerformers.map((p) => p.investment.id).toSet();
        expect(bottomIds, contains('inv6'));
      });

      test('regression: bottomPerformers first element has higher XIRR than last element', () {
        // This test specifically verifies the bug was fixed:
        // In the OLD code, the WORST performer was first (ascending order).
        // In the NEW code, the LEAST BAD of the bottom 5 is first (descending order).
        final investments = [
          makeInvestment(id: 'inv1', name: 'A'),
          makeInvestment(id: 'inv2', name: 'B'),
          makeInvestment(id: 'inv3', name: 'C'),
          makeInvestment(id: 'inv4', name: 'D'),
          makeInvestment(id: 'inv5', name: 'E'),
          makeInvestment(id: 'inv6', name: 'F (worst)'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 16000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 14000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
          ...makeCashFlows(investmentId: 'inv4', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv5', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv6', investAmount: 10000, returnAmount: 9000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.bottomPerformers.length, 5);
        // After fix: first element should have HIGHER XIRR than the last element
        expect(
          report.bottomPerformers.first.xirr,
          greaterThan(report.bottomPerformers.last.xirr),
          reason: 'bottomPerformers[0].xirr should be > bottomPerformers.last.xirr '
              '(descending order after bug fix — old code had ascending/worst-first order)',
        );
      });

      test('bottomPerformers limits to 5 when more than 5 investments exist', () {
        final investments = List.generate(
          8,
          (i) => makeInvestment(id: 'inv$i', name: 'Investment $i'),
        );
        final cashFlows = <CashFlowEntity>[];
        for (int i = 0; i < 8; i++) {
          cashFlows.addAll(
            makeCashFlows(
              investmentId: 'inv$i',
              investAmount: 10000,
              returnAmount: 9000.0 + i * 1000, // Increasing returns: 9k, 10k, 11k...
            ),
          );
        }

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.bottomPerformers.length, 5);
      });

      test('bottomPerformers equals allPerformances when fewer than 5 investments', () {
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 9000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.bottomPerformers.length, report.allPerformances.length);
        expect(report.bottomPerformers.length, 2);
      });
    });

    group('generateReport - profitability', () {
      test('counts profitable investments correctly', () {
        final investments = [
          makeInvestment(id: 'inv1', name: 'Profitable'),
          makeInvestment(id: 'inv2', name: 'Loss making'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 12000), // gain
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 8000),  // loss
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.totalInvestments, 2);
        expect(report.profitableCount, 1);
        expect(report.lossCount, 1);
        expect(report.profitabilityRate, 50.0);
      });

      test('all profitable investments', () {
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
          makeInvestment(id: 'inv3'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.profitableCount, 3);
        expect(report.lossCount, 0);
        expect(report.profitabilityRate, 100.0);
      });

      test('all loss-making investments', () {
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 9000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 8000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.profitableCount, 0);
        expect(report.lossCount, 2);
        expect(report.profitabilityRate, 0.0);
      });
    });

    group('generateReport - averageXIRR and medianXIRR', () {
      test('returns 0.0 average and median for empty investment list', () {
        final report = service.generateReport(
          allInvestments: [],
          allCashFlows: [],
        );

        expect(report.averageXIRR, 0.0);
        expect(report.medianXIRR, 0.0);
      });

      test('averageXIRR approximates arithmetic mean', () {
        // Two investments each with a known positive return
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 13000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // Both have positive XIRRs, so the average should be positive
        expect(report.averageXIRR, greaterThan(0.0));
        // Average should be between the two individual XIRRs
        final minXirr = report.allPerformances.map((p) => p.xirr).reduce((a, b) => a < b ? a : b);
        final maxXirr = report.allPerformances.map((p) => p.xirr).reduce((a, b) => a > b ? a : b);
        expect(report.averageXIRR, greaterThanOrEqualTo(minXirr));
        expect(report.averageXIRR, lessThanOrEqualTo(maxXirr));
      });

      test('medianXIRR equals middle value for odd number of investments', () {
        final investments = [
          makeInvestment(id: 'inv1'),
          makeInvestment(id: 'inv2'),
          makeInvestment(id: 'inv3'),
        ];
        final cashFlows = [
          ...makeCashFlows(investmentId: 'inv1', investAmount: 10000, returnAmount: 11000),
          ...makeCashFlows(investmentId: 'inv2', investAmount: 10000, returnAmount: 12000),
          ...makeCashFlows(investmentId: 'inv3', investAmount: 10000, returnAmount: 13000),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // Median is the middle of 3 sorted XIRR values
        final sortedXirrs = report.allPerformances.map((p) => p.xirr).toList()..sort();
        expect(report.medianXIRR, sortedXirrs[1]);
      });
    });

    group('generateReport - milestone detection', () {
      test('no milestones for investments without sufficient gains', () {
        final investments = [makeInvestment(id: 'inv1')];
        final cashFlows = [
          ...makeCashFlows(
            investmentId: 'inv1',
            investAmount: 10000,
            returnAmount: 10500, // 5% gain - below 10% threshold
          ),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        expect(report.recentMilestones, isEmpty);
      });

      test('detects 10% milestone', () {
        final investments = [makeInvestment(id: 'inv1')];
        final cashFlows = [
          // invest 10000, return 11100 → ~11% absolute return
          ...makeCashFlows(
            investmentId: 'inv1',
            investAmount: 10000,
            returnAmount: 11100,
          ),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        final milestonePercentages = report.recentMilestones.map((m) => m.milestonePercentage).toSet();
        expect(milestonePercentages, contains(10.0));
      });

      test('detects multiple milestones for high gains', () {
        final investments = [makeInvestment(id: 'inv1')];
        final cashFlows = [
          // invest 10000, return 21000 → 110% absolute return - crosses 10, 25, 50, 100 milestones
          ...makeCashFlows(
            investmentId: 'inv1',
            investAmount: 10000,
            returnAmount: 21000,
          ),
        ];

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        final milestonePercentages = report.recentMilestones.map((m) => m.milestonePercentage).toSet();
        expect(milestonePercentages, containsAll([10.0, 25.0, 50.0, 100.0]));
      });

      test('limits milestones to 10 most recent', () {
        // Create many investments that each cross multiple milestones
        final investments = List.generate(
          10,
          (i) => makeInvestment(id: 'inv$i', name: 'Investment $i'),
        );
        final cashFlows = <CashFlowEntity>[];
        for (int i = 0; i < 10; i++) {
          cashFlows.addAll(
            makeCashFlows(
              investmentId: 'inv$i',
              investAmount: 10000,
              returnAmount: 25000, // 150% gain - crosses 10%, 25%, 50%, 100%
            ),
          );
        }

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // Should be capped at 10 milestones
        expect(report.recentMilestones.length, lessThanOrEqualTo(10));
      });
    });

    group('generateReport - topPerformers and bottomPerformers consistency', () {
      test('topPerformers and bottomPerformers may overlap when few investments', () {
        // With exactly 5 investments, both top and bottom should cover all investments
        final investments = List.generate(
          5,
          (i) => makeInvestment(id: 'inv$i', name: 'Investment $i'),
        );
        final cashFlows = <CashFlowEntity>[];
        for (int i = 0; i < 5; i++) {
          cashFlows.addAll(
            makeCashFlows(
              investmentId: 'inv$i',
              investAmount: 10000,
              returnAmount: 10000.0 + (i + 1) * 1000,
            ),
          );
        }

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // With exactly 5 investments, both lists should contain all 5
        expect(report.topPerformers.length, 5);
        expect(report.bottomPerformers.length, 5);

        final topIds = report.topPerformers.map((p) => p.investment.id).toSet();
        final bottomIds = report.bottomPerformers.map((p) => p.investment.id).toSet();
        // Both should contain the same set of investment IDs
        expect(topIds, equals(bottomIds));
      });

      test('topPerformers is in descending order and bottomPerformers is in descending order', () {
        // Verify both lists maintain descending XIRR order
        final investments = List.generate(
          7,
          (i) => makeInvestment(id: 'inv$i', name: 'Investment $i'),
        );
        final cashFlows = <CashFlowEntity>[];
        for (int i = 0; i < 7; i++) {
          cashFlows.addAll(
            makeCashFlows(
              investmentId: 'inv$i',
              investAmount: 10000,
              returnAmount: 9000.0 + i * 1500, // Clearly different returns
            ),
          );
        }

        final report = service.generateReport(
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // topPerformers: descending order
        final topXirrs = report.topPerformers.map((p) => p.xirr).toList();
        for (int i = 0; i < topXirrs.length - 1; i++) {
          expect(
            topXirrs[i],
            greaterThanOrEqualTo(topXirrs[i + 1]),
            reason: 'topPerformers must be in descending XIRR order',
          );
        }

        // bottomPerformers: also descending order (after bug fix)
        final bottomXirrs = report.bottomPerformers.map((p) => p.xirr).toList();
        for (int i = 0; i < bottomXirrs.length - 1; i++) {
          expect(
            bottomXirrs[i],
            greaterThanOrEqualTo(bottomXirrs[i + 1]),
            reason: 'bottomPerformers must be in descending XIRR order after bug fix',
          );
        }
      });
    });

    group('generateReport - generatedAt timestamp', () {
      test('generatedAt is set to current time', () {
        final before = DateTime.now();
        final report = service.generateReport(
          allInvestments: [],
          allCashFlows: [],
        );
        final after = DateTime.now();

        expect(
          report.generatedAt.isAfter(before) || report.generatedAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          report.generatedAt.isBefore(after) || report.generatedAt.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });
  });

  group('InvestmentPerformance', () {
    test('isProfitable returns true when absoluteReturn is positive', () {
      final investment = makeInvestment(id: 'inv1');
      final performance = InvestmentPerformance(
        investment: investment,
        xirr: 0.10,
        absoluteReturn: 1000.0, // profit
        percentageReturn: 10.0,
        totalInvested: 10000.0,
        totalReturned: 11000.0,
        currentValue: 1000.0,
      );

      expect(performance.isProfitable, isTrue);
    });

    test('isProfitable returns false when absoluteReturn is negative', () {
      final investment = makeInvestment(id: 'inv1');
      final performance = InvestmentPerformance(
        investment: investment,
        xirr: -0.10,
        absoluteReturn: -1000.0, // loss
        percentageReturn: -10.0,
        totalInvested: 10000.0,
        totalReturned: 9000.0,
        currentValue: 1000.0,
      );

      expect(performance.isProfitable, isFalse);
    });

    test('category returns correct tier for various XIRR values', () {
      final investment = makeInvestment(id: 'inv1');

      InvestmentPerformance withXirr(double xirr) => InvestmentPerformance(
            investment: investment,
            xirr: xirr,
            absoluteReturn: 0,
            percentageReturn: 0,
            totalInvested: 0,
            totalReturned: 0,
            currentValue: 0,
          );

      expect(withXirr(0.20).category, PerformanceCategory.excellent); // >= 15%
      expect(withXirr(0.15).category, PerformanceCategory.excellent); // >= 15%
      expect(withXirr(0.12).category, PerformanceCategory.good);      // 10-15%
      expect(withXirr(0.10).category, PerformanceCategory.good);      // >= 10%
      expect(withXirr(0.07).category, PerformanceCategory.moderate);  // 5-10%
      expect(withXirr(0.05).category, PerformanceCategory.moderate);  // >= 5%
      expect(withXirr(0.03).category, PerformanceCategory.poor);      // 0-5%
      expect(withXirr(0.00).category, PerformanceCategory.poor);      // >= 0%
      expect(withXirr(-0.05).category, PerformanceCategory.loss);     // < 0%
    });
  });

  group('PerformanceReport', () {
    test('profitabilityRate returns 0 when no investments', () {
      // Manually construct a PerformanceReport with 0 investments
      final report = PerformanceReport(
        topPerformers: [],
        bottomPerformers: [],
        allPerformances: [],
        recentMilestones: [],
        averageXIRR: 0.0,
        medianXIRR: 0.0,
        totalInvestments: 0,
        profitableCount: 0,
        lossCount: 0,
        generatedAt: DateTime.now(),
      );

      expect(report.profitabilityRate, 0.0);
    });

    test('profitabilityRate calculates correctly', () {
      final report = PerformanceReport(
        topPerformers: [],
        bottomPerformers: [],
        allPerformances: [],
        recentMilestones: [],
        averageXIRR: 0.0,
        medianXIRR: 0.0,
        totalInvestments: 4,
        profitableCount: 3,
        lossCount: 1,
        generatedAt: DateTime.now(),
      );

      expect(report.profitabilityRate, 75.0);
    });
  });
}