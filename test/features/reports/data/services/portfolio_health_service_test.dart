import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/reports/data/services/portfolio_health_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/portfolio_health_report.dart';

void main() {
  group('PortfolioHealthService', () {
    late PortfolioHealthService service;

    setUp(() {
      service = PortfolioHealthService();
    });

    test('should calculate diversification correctly', () {
      final now = DateTime.now();
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stocks',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Bonds',
          type: InvestmentType.bonds,
          status: InvestmentStatus.open,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv3',
          name: 'FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
      ];

      final statsMap = {
        'inv1': const InvestmentStats(
          totalInvested: 60000,
          totalReturned: 0,
          netCashFlow: -60000,
          absoluteReturn: 0,
          moic: 0,
          xirr: 0.15,
          cashFlowCount: 1,
        ),
        'inv2': const InvestmentStats(
          totalInvested: 30000,
          totalReturned: 0,
          netCashFlow: -30000,
          absoluteReturn: 0,
          moic: 0,
          xirr: 0.08,
          cashFlowCount: 1,
        ),
        'inv3': const InvestmentStats(
          totalInvested: 10000,
          totalReturned: 0,
          netCashFlow: -10000,
          absoluteReturn: 0,
          moic: 0,
          xirr: 0.06,
          cashFlowCount: 1,
        ),
      };

      final report = service.generateReport(
        investments: investments,
        statsMap: statsMap,
        cashFlows: [],
      );

      expect(report.diversification.length, 3);
      expect(report.totalInvestments, 3);
      expect(report.activeInvestments, 3);
    });

    test('should calculate health score', () {
      final now = DateTime.now();
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
      ];

      final statsMap = {
        'inv1': const InvestmentStats(
          totalInvested: 10000,
          totalReturned: 0,
          netCashFlow: -10000,
          absoluteReturn: 0,
          moic: 0,
          xirr: 0.15,
          cashFlowCount: 1,
        ),
      };

      final report = service.generateReport(
        investments: investments,
        statsMap: statsMap,
        cashFlows: [],
      );

      // Verify score is calculated (could be any value depending on algorithm)
      expect(report.overallScore, isA<HealthScore>());
      expect(report.scoreValue, greaterThanOrEqualTo(0));
      expect(report.scoreValue, lessThanOrEqualTo(100));
    });

    test('should handle empty portfolio', () {
      final report = service.generateReport(
        investments: [],
        statsMap: {},
        cashFlows: [],
      );

      expect(report.totalInvestments, 0);
      expect(report.activeInvestments, 0);
      expect(report.diversification, isEmpty);
      expect(report.scoreValue, 0);
    });

    test('should exclude closed investments from health calculation', () {
      final now = DateTime.now();
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Active',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Closed',
          type: InvestmentType.stocks,
          status: InvestmentStatus.closed,
          startDate: now,
          createdAt: now,
          updatedAt: now,
          currency: 'USD',
        ),
      ];

      final statsMap = {
        'inv1': const InvestmentStats(
          totalInvested: 10000,
          totalReturned: 0,
          netCashFlow: -10000,
          absoluteReturn: 0,
          moic: 0,
          xirr: 0.15,
          cashFlowCount: 1,
        ),
      };

      final report = service.generateReport(
        investments: investments,
        statsMap: statsMap,
        cashFlows: [],
      );

      expect(report.totalInvestments, 2);
      expect(report.activeInvestments, 1); // Only open investment
    });
  });
}
