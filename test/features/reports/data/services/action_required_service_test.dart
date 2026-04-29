import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/action_required_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';

void main() {
  group('ActionRequiredService', () {
    late ActionRequiredService service;
    late DateTime now;

    setUp(() {
      service = ActionRequiredService();
      now = DateTime.now(); // Use actual now
    });

    test('should identify overdue maturities', () {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Overdue FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.subtract(const Duration(days: 5)), // 5 days ago
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        investments: investments,
        cashFlows: [],
        goals: [],
      );

      expect(report.allActions.length, greaterThan(0));
      final overdueAction = report.allActions.firstWhere(
        (a) => a.type == ActionType.maturity && a.priority == ActionPriority.critical,
      );
      expect(overdueAction.title, contains('Overdue'));
    });

    test('should identify critical maturities within 7 days', () {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Critical FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.add(const Duration(days: 5)), // 5 days from now
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        investments: investments,
        cashFlows: [],
        goals: [],
      );

      expect(report.allActions.length, 1);
      expect(report.criticalActions.length, 1);
      expect(report.criticalActions.first.type, ActionType.maturity);
    });

    test('should identify high priority maturities within 30 days', () {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Soon Maturing FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.add(const Duration(days: 26)), // 26 days from now
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        investments: investments,
        cashFlows: [],
        goals: [],
      );

      expect(report.allActions.length, 1);
      expect(report.highPriorityActions.length, 1);
      expect(report.highPriorityActions.first.type, ActionType.maturity);
    });

    test('should ignore closed investments', () {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Closed FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.add(const Duration(days: 5)), // Would be critical if open
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        investments: investments,
        cashFlows: [],
        goals: [],
      );

      expect(report.allActions, isEmpty);
    });

    test('should handle empty data', () {
      final report = service.generateReport(
        investments: [],
        cashFlows: [],
        goals: [],
      );

      expect(report.allActions, isEmpty);
      expect(report.criticalActions, isEmpty);
      expect(report.highPriorityActions, isEmpty);
      expect(report.mediumPriorityActions, isEmpty);
    });

    test('should count actions by priority', () {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Overdue',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.subtract(const Duration(days: 5)), // Overdue
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'High Priority',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: now.subtract(const Duration(days: 365)),
          maturityDate: now.add(const Duration(days: 26)), // High priority
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now.subtract(const Duration(days: 365)),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        investments: investments,
        cashFlows: [],
        goals: [],
      );

      expect(report.criticalActions.length, greaterThan(0));
      expect(report.highPriorityActions.length, greaterThan(0));
    });
  });
}
