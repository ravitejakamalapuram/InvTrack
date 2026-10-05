// A12 (#756): an income goal's target and income are monthly amounts. The
// goal report must say so, or a ₹10,000/month goal reads as a ₹10,000
// corpus target next to the corpus goals.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/reports/data/services/goal_progress_service.dart';
import 'package:inv_tracker/features/reports/data/services/report_csv_exporter.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';

GoalProgress _progress(GoalEntity goal, double current, double target) =>
    GoalProgress(
      goal: goal,
      currentAmount: current,
      targetAmount: target,
      progressPercent: current / target * 100,
      monthlyVelocity: 0,
      monthlyIncome: goal.isIncomeGoal ? current : 0,
      status: GoalStatus.onTrack,
      currentMilestone: GoalMilestone.forPercentage(current / target * 100),
      achievedMilestones: GoalMilestone.achievedMilestones(
        current / target * 100,
      ),
      linkedInvestmentCount: 1,
      calculatedAt: DateTime(2026, 10, 4),
    );

GoalEntity _goal(String id, GoalType type, {double? monthlyIncome}) =>
    GoalEntity(
      id: id,
      name: id,
      type: type,
      targetAmount: 1000000,
      targetMonthlyIncome: monthlyIncome,
      trackingMode: GoalTrackingMode.all,
      icon: '🎯',
      colorValue: 0xFF3B82F6,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currency: 'INR',
    );

void main() {
  test('income goal amounts are marked as monthly', () {
    final income = _goal(
      'Passive income',
      GoalType.incomeTarget,
      monthlyIncome: 10000,
    );
    final house = _goal('House', GoalType.targetAmount);
    final report = GoalProgressService().generateReport(
      allGoals: [income, house],
      progressMap: {
        income.id: _progress(income, 6250, 10000),
        house.id: _progress(house, 600000, 1000000),
      },
    );

    final rows = ReportCsvExporter().rowsFor(
      report,
      ReportType.goalProgress,
      currencySymbol: '₹',
      locale: 'en_IN',
    );

    final incomeRow = rows.firstWhere((r) => r.isNotEmpty && r[0] == income.id);
    final houseRow = rows.firstWhere((r) => r.isNotEmpty && r[0] == house.id);
    expect(incomeRow[2], '₹10,000.00/mo');
    expect(incomeRow[3], '₹6,250.00/mo');
    expect(houseRow[2], '₹10,00,000.00');
    expect(houseRow[3], '₹6,00,000.00');
  });
}
