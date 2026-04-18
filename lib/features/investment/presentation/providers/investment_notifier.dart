/// State notifier for investment mutations (CRUD operations).
/// Handles all write operations for investments and cash flows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/core/utils/analytics_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:uuid/uuid.dart';

// ============ INVESTMENT NOTIFIER (ACTIONS) ============

final investmentNotifierProvider =
    NotifierProvider<InvestmentNotifier, AsyncValue<void>>(
      InvestmentNotifier.new,
    );

class InvestmentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Create a new investment.
  /// Throws [ValidationException] if name is empty or exceeds max length.
  Future<InvestmentEntity> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    // New enhanced data capture fields
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    // Multi-currency support
    String? currency,
  }) async {
    // Input validation
    _validateName(name);
    _validateNotes(notes);

    state = const AsyncValue.loading();
    try {
      final investment = InvestmentEntity(
        id: const Uuid().v4(),
        name: name.trim(),
        type: type,
        status: InvestmentStatus.open,
        notes: notes?.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        // New enhanced data capture fields
        startDate: startDate,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
        interestPayoutMode: interestPayoutMode,
        autoRenewal: autoRenewal,
        riskLevel: riskLevel,
        compoundingFrequency: compoundingFrequency,
        // Multi-currency (defaults to USD if not provided)
        currency: currency ?? 'USD',
      );

      // Track performance of investment creation
      await ref
          .read(performanceServiceProvider)
          .trackOperation(
            'investment_create',
            () => ref
                .read(investmentRepositoryProvider)
                .createInvestment(investment),
            attributes: {'investment_type': type.name},
          );

      // Track analytics event
      ref
          .read(analyticsServiceProvider)
          .logInvestmentCreated(
            investmentType: type.name,
            hasNotes: notes != null && notes.trim().isNotEmpty,
          );

      // Schedule income reminder if frequency is set
      if (incomeFrequency != null) {
        await _scheduleIncomeReminder(investment);
      }

      // Schedule maturity reminders if maturity date is set
      if (maturityDate != null) {
        await _scheduleMaturityReminders(investment);
      }

      // Cancel new user activation nudges since user has added an investment
      await ref.read(notificationServiceProvider).cancelActivationSequence();

      _invalidateAll();
      state = const AsyncValue.data(null);
      return investment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update an existing investment.
  /// Throws [ValidationException] if name is empty or exceeds max length.
  Future<void> updateInvestment({
    required String id,
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    // New enhanced data capture fields
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    // Multi-currency support
    String? currency,
  }) async {
    // Input validation
    _validateName(name);
    _validateNotes(notes);

    state = const AsyncValue.loading();
    try {
      final existing = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      if (existing == null) throw DataException.notFound('Investment', id);

      final updated = existing.copyWith(
        name: name.trim(),
        type: type,
        notes: notes?.trim(),
        updatedAt: DateTime.now(),
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        // New enhanced data capture fields
        startDate: startDate,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
        interestPayoutMode: interestPayoutMode,
        autoRenewal: autoRenewal,
        riskLevel: riskLevel,
        compoundingFrequency: compoundingFrequency,
        // Multi-currency
        currency: currency,
      );
      final repo = ref.read(investmentRepositoryProvider);

      // Track performance of investment update
      await ref.read(performanceServiceProvider).trackOperation(
        'investment_update',
        () async {
          if (existing.isArchived) {
            await repo.updateArchivedInvestment(updated);
          } else {
            await repo.updateInvestment(updated);
          }
        },
        attributes: {
          'investment_type': type.name,
          'is_archived': existing.isArchived.toString(),
        },
      );

      // Update income reminder based on new frequency
      if (incomeFrequency != null) {
        await _scheduleIncomeReminder(updated);
      } else {
        // Cancel reminder if frequency was removed
        await _cancelIncomeReminder(id);
      }

      // Update maturity reminders based on new maturity date
      if (maturityDate != null) {
        await _scheduleMaturityReminders(updated);
      } else {
        // Cancel reminders if maturity date was removed
        await _cancelMaturityReminders(id);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Close an investment
  Future<void> closeInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch investment first for analytics
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      await ref.read(investmentRepositoryProvider).closeInvestment(id);
      // Cancel income reminder for closed investment
      await _cancelIncomeReminder(id);
      // Cancel maturity reminders for closed investment
      await _cancelMaturityReminders(id);

      // Track analytics
      if (investment != null) {
        ref
            .read(analyticsServiceProvider)
            .logInvestmentClosed(investmentType: investment.type.name);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reopen a closed investment
  Future<void> reopenInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      await ref.read(investmentRepositoryProvider).reopenInvestment(id);
      if (investment != null) {
        // Re-schedule income reminder if investment has income frequency
        if (investment.incomeFrequency != null) {
          await _scheduleIncomeReminder(investment);
        }
        // Re-schedule maturity reminders if investment has maturity date
        if (investment.maturityDate != null) {
          await _scheduleMaturityReminders(investment);
        }

        // Track analytics
        ref
            .read(analyticsServiceProvider)
            .logInvestmentReopened(investmentType: investment.type.name);
      }
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Archive an investment (hide from active view)
  Future<void> archiveInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch investment first for analytics
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      await ref.read(investmentRepositoryProvider).archiveInvestment(id);
      // Cancel notifications for archived investment
      await _cancelIncomeReminder(id);
      await _cancelMaturityReminders(id);

      // Track analytics
      if (investment != null) {
        ref
            .read(analyticsServiceProvider)
            .logInvestmentArchived(investmentType: investment.type.name);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Unarchive an investment (restore to active view)
  Future<void> unarchiveInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch from archived collection since that's where the investment is
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getArchivedInvestmentById(id);
      await ref.read(investmentRepositoryProvider).unarchiveInvestment(id);
      if (investment != null) {
        // Re-schedule reminders if applicable
        if (investment.incomeFrequency != null) {
          await _scheduleIncomeReminder(investment);
        }
        if (investment.maturityDate != null) {
          await _scheduleMaturityReminders(investment);
        }

        // Track analytics
        ref
            .read(analyticsServiceProvider)
            .logInvestmentUnarchived(investmentType: investment.type.name);
      }
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete an investment
  Future<void> deleteInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch investment first for analytics
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      // Cancel all reminders before deleting
      await _cancelIncomeReminder(id);
      await _cancelMaturityReminders(id);

      // Track performance of investment deletion
      await ref
          .read(performanceServiceProvider)
          .trackOperation(
            'investment_delete',
            () => ref.read(investmentRepositoryProvider).deleteInvestment(id),
            attributes: {'investment_type': investment?.type.name ?? 'unknown'},
          );

      // Track analytics
      if (investment != null) {
        ref
            .read(analyticsServiceProvider)
            .logInvestmentDeleted(investmentType: investment.type.name);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete an archived investment
  Future<void> deleteArchivedInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch investment first for analytics
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getArchivedInvestmentById(id);
      // No need to cancel reminders - archived investments don't have them
      await ref.read(investmentRepositoryProvider).deleteArchivedInvestment(id);

      // Track analytics
      if (investment != null) {
        ref
            .read(analyticsServiceProvider)
            .logInvestmentDeleted(investmentType: investment.type.name);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk delete multiple investments and their cash flows.
  Future<int> bulkDelete(List<String> investmentIds) async {
    if (investmentIds.isEmpty) return 0;

    state = const AsyncValue.loading();
    try {
      final deletedCount = await ref
          .read(investmentRepositoryProvider)
          .bulkDelete(investmentIds);
      _invalidateAll();
      state = const AsyncValue.data(null);
      return deletedCount;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Add a cash flow to an investment.
  /// Throws [ValidationException] if amount is not positive.
  Future<void> addCashFlow({
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    String? currency,
  }) async {
    // Input validation
    _validateAmount(amount);
    _validateNotes(notes);

    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: const Uuid().v4(),
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date,
        notes: notes?.trim(),
        createdAt: DateTime.now(),
        currency: currency ?? 'USD',
      );
      await ref.read(investmentRepositoryProvider).addCashFlow(cashFlow);

      // Track analytics event
      ref
          .read(analyticsServiceProvider)
          .logCashFlowAdded(
            flowType: type.name,
            amountRange: getAmountRange(amount),
          );

      // Check for milestone achievements after adding return cash flows
      if (type == CashFlowType.income || type == CashFlowType.returnFlow) {
        await _checkMilestoneAfterCashFlow(investmentId);
      }

      // Check for goal milestone achievements after any cash flow
      await _checkGoalMilestonesAfterCashFlow();

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update a cash flow.
  /// Throws [ValidationException] if amount is not positive.
  Future<void> updateCashFlow({
    required String id,
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    required DateTime createdAt,
    String? currency,
  }) async {
    // Input validation
    _validateAmount(amount);
    _validateNotes(notes);

    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date,
        notes: notes?.trim(),
        createdAt: createdAt,
        currency: currency ?? 'USD',
      );
      await ref.read(investmentRepositoryProvider).updateCashFlow(cashFlow);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete a cash flow
  Future<void> deleteCashFlow(String id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(investmentRepositoryProvider).deleteCashFlow(id);
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Merge multiple investments into one
  Future<void> mergeInvestments(
    List<String> investmentIds,
    String newName, {
    InvestmentType? type,
  }) async {
    if (investmentIds.length < 2) return;

    state = const AsyncValue.loading();
    try {
      final repo = ref.read(investmentRepositoryProvider);

      // Get all investments to merge
      final allInvestments = await ref.read(allInvestmentsProvider.future);
      final toMerge = allInvestments
          .where((i) => investmentIds.contains(i.id))
          .toList();

      if (toMerge.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      // Use provided type, or fall back to most common type
      InvestmentType finalType;
      if (type != null) {
        finalType = type;
      } else {
        final typeCount = <InvestmentType, int>{};
        for (final inv in toMerge) {
          typeCount[inv.type] = (typeCount[inv.type] ?? 0) + 1;
        }
        // Optimization: Replace .reduce() with a standard loop to avoid closure overhead
        int maxCount = -1;
        InvestmentType? mostCommonType;
        for (final entry in typeCount.entries) {
          if (entry.value > maxCount) {
            maxCount = entry.value;
            mostCommonType = entry.key;
          }
        }
        finalType = mostCommonType ?? InvestmentType.other;
      }

      // Create new merged investment
      final now = DateTime.now();
      final newInvestmentId = const Uuid().v4();
      final newInvestment = InvestmentEntity(
        id: newInvestmentId,
        name: newName,
        type: finalType,
        status: toMerge.any((i) => i.status == InvestmentStatus.open)
            ? InvestmentStatus.open
            : InvestmentStatus.closed,
        notes: 'Merged from: ${toMerge.map((i) => i.name).join(', ')}',
        createdAt: now,
        updatedAt: now,
      );

      // Collect all cash flows from merged investments
      final newCashFlows = <CashFlowEntity>[];
      for (final inv in toMerge) {
        final cashFlows = await repo.getCashFlowsByInvestment(inv.id);
        for (final cf in cashFlows) {
          newCashFlows.add(
            CashFlowEntity(
              id: const Uuid().v4(),
              investmentId: newInvestmentId,
              type: cf.type,
              amount: cf.amount,
              date: cf.date,
              notes: cf.notes != null
                  ? '${cf.notes} (from ${inv.name})'
                  : 'From ${inv.name}',
              createdAt: now,
            ),
          );
        }
      }

      // Use bulk import for efficient batch writes
      await repo.bulkImport(
        investments: [newInvestment],
        cashFlows: newCashFlows,
      );

      // Delete old investments
      for (final id in investmentIds) {
        await repo.deleteInvestment(id);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk import investments with their cash flows.
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Track performance of bulk import
      final result = await ref
          .read(performanceServiceProvider)
          .trackOperation(
            'investment_bulk_import',
            () => ref
                .read(investmentRepositoryProvider)
                .bulkImport(investments: investments, cashFlows: cashFlows),
            metrics: {
              'investment_count': investments.length,
              'cash_flow_count': cashFlows.length,
            },
          );

      _invalidateAll();
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Note: With stream-based architecture, manual invalidation is largely unnecessary.
  // Firestore streams auto-update, and derived providers reactively recompute.
  // This method is kept for edge cases (e.g., forcing refresh after error recovery).
  void _invalidateAll() {
    ref.invalidate(allInvestmentsProvider);
    ref.invalidate(allCashFlowsStreamProvider);
    // Also invalidate archived providers for consistency
    ref.invalidate(archivedInvestmentsProvider);
  }

  // ============ VALIDATION HELPERS ============

  /// Validates investment/cash flow name.
  /// Throws [ValidationException] if name is empty or exceeds max length.
  void _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException.emptyField('Name');
    }
    if (trimmed.length > ValidationConstants.maxNameLength) {
      throw ValidationException.tooLong(
        'Name',
        ValidationConstants.maxNameLength,
      );
    }
  }

  /// Validates amount for cash flows.
  /// Throws [ValidationException] if amount is not positive.
  void _validateAmount(double amount) {
    if (amount <= 0) {
      throw ValidationException.invalidAmount(amount);
    }
  }

  /// Validates optional notes field.
  /// Throws [ValidationException] if notes exceed max length.
  void _validateNotes(String? notes) {
    if (notes != null &&
        notes.trim().length > ValidationConstants.maxNotesLength) {
      throw ValidationException.tooLong(
        'Notes',
        ValidationConstants.maxNotesLength,
      );
    }
  }

  // ============ Income Reminder Helpers ============

  /// Schedule an income reminder for an investment
  Future<void> _scheduleIncomeReminder(InvestmentEntity investment) async {
    if (investment.incomeFrequency == null) return;

    try {
      // Get the last income date from cash flows
      final cashFlows = await ref
          .read(investmentRepositoryProvider)
          .getCashFlowsByInvestment(investment.id);

      DateTime? lastIncomeDate;
      for (final cf in cashFlows) {
        if (cf.type == CashFlowType.income) {
          if (lastIncomeDate == null || cf.date.isAfter(lastIncomeDate)) {
            lastIncomeDate = cf.date;
          }
        }
      }

      await ref
          .read(notificationServiceProvider)
          .scheduleIncomeReminder(
            investmentId: investment.id,
            investmentName: investment.name,
            monthsBetweenPayments:
                investment.incomeFrequency!.monthsBetweenPayments,
            lastIncomeDate: lastIncomeDate,
          );
    } catch (e) {
      // Don't fail the main operation if notification scheduling fails
      // Just log and continue
    }
  }

  /// Cancel income reminder for an investment
  Future<void> _cancelIncomeReminder(String investmentId) async {
    try {
      await ref
          .read(notificationServiceProvider)
          .cancelIncomeReminder(investmentId);
    } catch (e) {
      // Don't fail the main operation if notification cancellation fails
    }
  }

  // ============ Maturity Reminder Helpers ============

  /// Schedule maturity reminders for an investment
  Future<void> _scheduleMaturityReminders(InvestmentEntity investment) async {
    if (investment.maturityDate == null) return;

    try {
      await ref
          .read(notificationServiceProvider)
          .scheduleMaturityReminders(
            investmentId: investment.id,
            investmentName: investment.name,
            maturityDate: investment.maturityDate!,
          );
    } catch (e) {
      // Don't fail the main operation if notification scheduling fails
    }
  }

  /// Cancel maturity reminders for an investment
  Future<void> _cancelMaturityReminders(String investmentId) async {
    try {
      await ref
          .read(notificationServiceProvider)
          .cancelMaturityReminders(investmentId);
    } catch (e) {
      // Don't fail the main operation if notification cancellation fails
    }
  }

  // ============ Milestone Helpers ============

  /// Check for milestone achievements after adding a cash flow
  Future<void> _checkMilestoneAfterCashFlow(String investmentId) async {
    try {
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(investmentId);
      if (investment == null) return;

      final cashFlows = await ref
          .read(investmentRepositoryProvider)
          .getCashFlowsByInvestment(investmentId);

      // Calculate totals
      double totalInvested = 0;
      double totalReturned = 0;
      for (final cf in cashFlows) {
        if (cf.type == CashFlowType.invest || cf.type == CashFlowType.fee) {
          totalInvested += cf.amount;
        } else {
          totalReturned += cf.amount;
        }
      }

      // Check for milestone notification
      await ref
          .read(notificationServiceProvider)
          .checkAndShowMilestone(
            investmentId: investmentId,
            investmentName: investment.name,
            totalInvested: totalInvested,
            totalReturned: totalReturned,
          );
    } catch (e) {
      // Don't fail the main operation if milestone check fails
    }
  }

  /// Check for goal milestone achievements after adding a cash flow
  Future<void> _checkGoalMilestonesAfterCashFlow() async {
    try {
      // Fetch data directly from repository to ensure fresh data
      final goalRepository = ref.read(goalRepositoryProvider);
      final investmentRepository = ref.read(investmentRepositoryProvider);

      // Get all active goals directly
      final goals = await goalRepository.watchActiveGoals().first;
      if (goals.isEmpty) return;

      // Get all investments
      final investments = await investmentRepository.getAllInvestments();

      // Get all cash flows
      final cashFlows = await investmentRepository.getAllCashFlows();

      final notificationService = ref.read(notificationServiceProvider);

      // Check each goal for milestone achievements and alerts
      for (final goal in goals) {
        final progress = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: investments,
          allCashFlows: cashFlows,
        );

        // Check for milestone achievements
        // **BUG FIX**: Pass full goal entity and persist updated goal to Firestore
        final updatedGoal = await notificationService.checkAndShowGoalMilestone(
          goal: goal,
          progressPercent: progress.progressPercent,
          currentValue: progress.currentAmount,
          targetValue: goal.targetAmount,
        );

        // Persist updated goal if milestone was sent
        if (updatedGoal != null && updatedGoal != goal) {
          // Use goals repository to update (need to inject/access it)
          // For now, the handler will mark in SharedPreferences as fallback
          // TODO: Inject GoalsRepository to persist updatedGoal
        }

        // Check for at-risk goals (status is behind)
        if (progress.status == GoalStatus.behind) {
          await notificationService.showGoalAtRiskNotification(
            goalId: goal.id,
            goalName: goal.name,
            progressPercent: progress.progressPercent,
            targetDate: goal.targetDate,
            projectedDate: progress.projectedCompletionDate,
          );
        }

        // Check for stale goals (no activity for X days)
        final lastActivityDate = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: investments,
          allCashFlows: cashFlows,
        );
        await notificationService.showGoalStaleNotification(
          goalId: goal.id,
          goalName: goal.name,
          lastActivityDate: lastActivityDate,
        );
      }
    } catch (e) {
      // Don't fail the main operation if goal milestone check fails
      // Error logged in debug mode
    }
  }
}
