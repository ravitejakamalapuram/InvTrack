import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/reports/data/services/maturity_calendar_service.dart';

void main() {
  group('MaturityCalendarService', () {
    late MaturityCalendarService service;

    setUp(() {
      service = MaturityCalendarService();
    });

    test('should identify investments maturing in next 30 days', () {
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: 'inv1',
        name: 'Maturing Soon',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        startDate: now.subtract(const Duration(days: 365)),
        maturityDate: now.add(const Duration(days: 15)),
        createdAt: now,
        updatedAt: now,
        currency: 'USD',
      );

      final statsMap = {
        'inv1': const InvestmentStats(
          totalInvested: 10000.0,
          totalReturned: 500.0,
          netCashFlow: -9500.0,
          absoluteReturn: 5.0,
          moic: 0.05,
          xirr: 0.05,
          cashFlowCount: 2,
        ),
      };

      final report = service.generateReport(
        investments: [investment],
        statsMap: statsMap,
      );

      expect(report.upcoming30Days.length, 1);
      expect(report.upcoming30Days.first.investment.id, 'inv1');
      expect(report.upcoming30Days.first.maturityAmount, 10000.0);
      expect(report.totalUpcoming30Days, 10000.0);
    });

    test('should identify investments maturing in next 90 days', () {
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: 'inv2',
        name: 'Maturing in 60 Days',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        startDate: now.subtract(const Duration(days: 365)),
        maturityDate: now.add(const Duration(days: 60)),
        createdAt: now,
        updatedAt: now,
        currency: 'USD',
      );

      final statsMap = {
        'inv2': const InvestmentStats(
          totalInvested: 20000.0,
          totalReturned: 1000.0,
          netCashFlow: -19000.0,
          absoluteReturn: 5.0,
          moic: 0.05,
          xirr: 0.05,
          cashFlowCount: 2,
        ),
      };

      final report = service.generateReport(
        investments: [investment],
        statsMap: statsMap,
      );

      expect(report.next90Days.length, 1);
      expect(report.totalNext90Days, 20000.0);
    });

    test('should handle investments without maturity dates', () {
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: 'inv3',
        name: 'No Maturity',
        type: InvestmentType.stocks,
        status: InvestmentStatus.open,
        startDate: now,
        maturityDate: null, // No maturity date
        createdAt: now,
        updatedAt: now,
        currency: 'USD',
      );

      final report = service.generateReport(
        investments: [investment],
        statsMap: {},
      );

      expect(report.upcoming30Days, isEmpty);
      expect(report.next90Days, isEmpty);
      expect(report.totalUpcoming30Days, 0.0);
    });

    test('should skip already matured investments', () {
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: 'inv4',
        name: 'Already Matured',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.closed,
        startDate: now.subtract(const Duration(days: 365)),
        maturityDate: now.subtract(const Duration(days: 30)), // Past date
        createdAt: now,
        updatedAt: now,
        currency: 'USD',
      );

      final report = service.generateReport(
        investments: [investment],
        statsMap: {},
      );

      expect(report.upcoming30Days, isEmpty);
      expect(report.next90Days, isEmpty);
    });

    test('should handle empty data', () {
      final report = service.generateReport(
        investments: [],
        statsMap: {},
      );

      expect(report.upcoming30Days, isEmpty);
      expect(report.next90Days, isEmpty);
      expect(report.beyond90Days, isEmpty);
      expect(report.totalUpcoming30Days, 0.0);
      expect(report.totalNext90Days, 0.0);
    });
  });
}
