/// State notifier for investment mutations (CRUD operations).
/// Handles all write operations for investments and cash flows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/analytics_utils.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:uuid/uuid.dart';

// ============ INVESTMENT NOTIFIER (ACTIONS) ============

final investmentNotifierProvider =
    NotifierProvider<InvestmentNotifier, AsyncValue<void>>(
      InvestmentNotifier.new,
    );

class InvestmentNotifier extends Notifier<AsyncValue<void>> {
  /// Goal milestones (%) checked after a cash flow.
  static const _goalMilestones = [25.0, 50.0, 75.0, 100.0];

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
    // Text typed in the "Custom type" field of an investment of type Other
    String? customTypeLabel,
  }) async {
    // Input validation
    _validateName(name);
    _validateNotes(notes);
    _validateCustomTypeLabel(type, customTypeLabel);

    state = const AsyncValue.loading();
    try {
      final customType = await _resolveCustomType(type, customTypeLabel);
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
        // Multi-currency (defaults to the user's base currency)
        currency: currency ?? ref.read(currencyCodeProvider),
        customTypeId: customType.id,
        customTypeLabel: customType.label,
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
  /// Every optional argument is the edit form's value, and null clears the
  /// stored one, so a caller must pass every field it does not mean to clear.
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
    // Text typed in the "Custom type" field of an investment of type Other;
    // null or blank clears the custom type.
    String? customTypeLabel,
  }) async {
    // Input validation
    _validateName(name);
    _validateNotes(notes);
    _validateCustomTypeLabel(type, customTypeLabel);

    state = const AsyncValue.loading();
    try {
      final existing = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(id);
      if (existing == null) throw DataException.notFound('Investment', id);
      final customType = await _resolveCustomType(
        type,
        customTypeLabel,
        existing: existing,
      );
      // The current value is in the stored currency; it means nothing in
      // another one, so a currency change clears it (money rule 2), unless
      // dated valuations in the new currency are on record: the pair then
      // mirrors the latest of them, like every other write of it. Left null,
      // it would read as a value cleared by an older app, and hide them.
      final newCurrency = currency ?? existing.currency;
      final keepsValue = newCurrency == existing.currency;
      final mirror = keepsValue
          ? null
          : await _mirrorInCurrency(existing.id, newCurrency);

      // Built explicitly, not with copyWith: the edit form sends every
      // optional field, and null means the user cleared it. copyWith would
      // keep the old value (and its reminders would return on next launch).
      // Only identity and lifecycle fields come from the stored investment.
      final updated = InvestmentEntity(
        id: existing.id,
        name: name.trim(),
        type: type,
        status: existing.status,
        notes: notes?.trim(),
        createdAt: existing.createdAt,
        closedAt: existing.closedAt,
        updatedAt: DateTime.now(),
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        isArchived: existing.isArchived,
        // New enhanced data capture fields
        startDate: startDate,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
        interestPayoutMode: interestPayoutMode,
        autoRenewal: autoRenewal,
        riskLevel: riskLevel,
        compoundingFrequency: compoundingFrequency,
        // Multi-currency: no currency from the form keeps the stored one
        currency: newCurrency,
        // Not on the edit form: set through setCurrentValue only.
        currentValue: keepsValue ? existing.currentValue : mirror?.amount,
        currentValueDate: keepsValue
            ? existing.currentValueDate
            : mirror?.effectiveDate,
        customTypeId: customType.id,
        customTypeLabel: customType.label,
      );
      final repo = ref.read(investmentRepositoryProvider);
      // With dated valuations on, the pair mirrors the latest snapshot and is
      // written with it: an edit that read it earlier must not send it back
      // (a currency change still clears it, above).
      final preserveValue =
          keepsValue && ref.read(valuationSnapshotsActiveProvider);

      // Track performance of investment update
      await ref.read(performanceServiceProvider).trackOperation(
        'investment_update',
        () async {
          if (existing.isArchived) {
            await repo.updateArchivedInvestment(
              updated,
              preserveCurrentValue: preserveValue,
            );
          } else {
            await repo.updateInvestment(
              updated,
              preserveCurrentValue: preserveValue,
            );
          }
        },
        attributes: {
          'investment_type': type.name,
          'is_archived': existing.isArchived.toString(),
        },
      );

      await _syncReminders(updated);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sets the user's current value of an open investment, in the
  /// investment's currency, as of [date] (date-only, not in the future).
  /// It becomes the terminal inflow of its XIRR, MOIC and return %.
  /// Throws [ValidationException] for a negative or non-finite value, a
  /// future date, or an investment that is not open.
  Future<void> setCurrentValue({
    required String id,
    required double value,
    required DateTime date,
  }) async {
    if (!value.isFinite || value < 0) {
      // No amount in the message: it may reach logs (money rule 7).
      throw ValidationException(
        userMessage: 'Enter a value of 0 or more.',
        technicalMessage:
            'Validation failed: current value is negative or '
            'not finite',
      );
    }
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    if (day.isAfter(DateTime(now.year, now.month, now.day))) {
      throw ValidationException.invalidDate(date);
    }
    if (ref.read(valuationSnapshotsActiveProvider)) {
      // Dated valuations are on: the value is a snapshot, and the pair is
      // written with it.
      await _viaValuations(
        () => ref
            .read(valuationNotifierProvider.notifier)
            .setValuation(
              investmentId: id,
              amount: value,
              date: day,
              replaceSameDay: true,
            ),
      );
      return;
    }
    await _writeCurrentValue(id, (existing) {
      if (!existing.isOpen) {
        throw ValidationException(
          userMessage: 'Only open investments have a current value.',
          technicalMessage: 'setCurrentValue on a closed investment',
        );
      }
      final rounded = MoneyPrecision.round(
        value,
        currencyCode: _requireCurrency(existing.currency),
      );
      return _withCurrentValue(existing, rounded, day);
    });
  }

  /// Removes the user's current value, so the estimate (if any) applies.
  Future<void> clearCurrentValue(String id) async {
    if (ref.read(valuationSnapshotsActiveProvider)) {
      // The latest snapshot is the value shown; a value only the pair holds
      // (no snapshot yet) is cleared the old way, below.
      var cleared = false;
      await _viaValuations(() async {
        cleared = await ref
            .read(valuationNotifierProvider.notifier)
            .clearLatestValuation(id);
      });
      if (cleared) return;
    }
    await _writeCurrentValue(
      id,
      (existing) => _withCurrentValue(existing, null, null),
    );
  }

  /// Runs a dated valuation write on behalf of the old entry points.
  Future<void> _viaValuations(Future<void> Function() write) async {
    state = const AsyncValue.loading();
    try {
      await write();
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> _writeCurrentValue(
    String id,
    InvestmentEntity Function(InvestmentEntity existing) update,
  ) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(investmentRepositoryProvider);
      final existing = await repo.getInvestmentById(id);
      if (existing == null) throw DataException.notFound('Investment', id);
      final updated = update(existing);
      if (existing.isArchived) {
        await repo.updateArchivedInvestment(updated);
      } else {
        await repo.updateInvestment(updated);
      }
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// [existing] with its current value replaced, including by null, which
  /// copyWith cannot do.
  InvestmentEntity _withCurrentValue(
    InvestmentEntity existing,
    double? value,
    DateTime? date,
  ) => InvestmentEntity(
    id: existing.id,
    name: existing.name,
    type: existing.type,
    status: existing.status,
    notes: existing.notes,
    createdAt: existing.createdAt,
    closedAt: existing.closedAt,
    updatedAt: DateTime.now(),
    maturityDate: existing.maturityDate,
    incomeFrequency: existing.incomeFrequency,
    isArchived: existing.isArchived,
    startDate: existing.startDate,
    expectedRate: existing.expectedRate,
    tenureMonths: existing.tenureMonths,
    platform: existing.platform,
    interestPayoutMode: existing.interestPayoutMode,
    autoRenewal: existing.autoRenewal,
    riskLevel: existing.riskLevel,
    compoundingFrequency: existing.compoundingFrequency,
    currency: existing.currency,
    currentValue: value,
    currentValueDate: date,
    customTypeId: existing.customTypeId,
    customTypeLabel: existing.customTypeLabel,
  );

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
        // An archived investment stays archived, so it gets no reminders.
        await _syncReminders(
          investment.copyWith(status: InvestmentStatus.open),
        );

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
        // Only an open investment gets its reminders back.
        await _syncReminders(investment.copyWith(isArchived: false));

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
  /// Throws [ValidationException] if amount is not positive (or rounds
  /// to zero in its currency) or the currency is blank.
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
    final String flowCurrency = _requireCurrency(
      currency ?? ref.read(currencyCodeProvider),
    );
    final roundedAmount = MoneyPrecision.round(
      amount,
      currencyCode: flowCurrency,
    );
    _validateAmount(roundedAmount);

    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: const Uuid().v4(),
        investmentId: investmentId,
        type: type,
        amount: roundedAmount,
        date: date,
        notes: notes?.trim(),
        createdAt: DateTime.now(),
        currency: flowCurrency,
      );
      await ref.read(investmentRepositoryProvider).addCashFlow(cashFlow);

      // Track analytics event
      ref
          .read(analyticsServiceProvider)
          .logCashFlowAdded(
            flowType: type.name,
            amountRange: getAmountRange(roundedAmount),
          );

      // Check for milestone achievements after adding return cash flows
      if (type == CashFlowType.income || type == CashFlowType.returnFlow) {
        await _checkMilestoneAfterCashFlow(investmentId);
      }

      // Check for goal milestone achievements after any cash flow
      await _checkGoalMilestonesAfterCashFlow(cashFlow.id);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update a cash flow.
  /// Throws [ValidationException] if amount is not positive (or rounds
  /// to zero in its currency) or the currency is blank.
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
    final String flowCurrency = _requireCurrency(
      currency ?? ref.read(currencyCodeProvider),
    );
    final roundedAmount = MoneyPrecision.round(
      amount,
      currencyCode: flowCurrency,
    );
    _validateAmount(roundedAmount);

    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        amount: roundedAmount,
        date: date,
        notes: notes?.trim(),
        createdAt: createdAt,
        currency: flowCurrency,
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

      // Create new merged investment, keeping the sources' currency (base
      // currency if they differ) and their terms. Start = earliest start,
      // maturity = latest maturity; other terms come from the first source
      // that has them.
      final now = DateTime.now();
      final newInvestmentId = const Uuid().v4();
      DateTime? earliestStart;
      DateTime? latestMaturity;
      for (final inv in toMerge) {
        final start = inv.startDate;
        if (start != null &&
            (earliestStart == null || start.isBefore(earliestStart))) {
          earliestStart = start;
        }
        final maturity = inv.maturityDate;
        if (maturity != null &&
            (latestMaturity == null || maturity.isAfter(latestMaturity))) {
          latestMaturity = maturity;
        }
      }
      T? firstSet<T>(T? Function(InvestmentEntity) field) {
        for (final inv in toMerge) {
          final value = field(inv);
          if (value != null) return value;
        }
        return null;
      }

      // A merged Other investment keeps the custom type of the first source
      // that has one.
      final customTypeSource = finalType == InvestmentType.other
          ? toMerge.where(
              (i) =>
                  i.type == InvestmentType.other && i.customTypeLabel != null,
            )
          : const <InvestmentEntity>[];
      final newInvestment = InvestmentEntity(
        id: newInvestmentId,
        name: newName,
        type: finalType,
        customTypeId: customTypeSource.firstOrNull?.customTypeId,
        customTypeLabel: customTypeSource.firstOrNull?.customTypeLabel,
        status: toMerge.any((i) => i.status == InvestmentStatus.open)
            ? InvestmentStatus.open
            : InvestmentStatus.closed,
        notes: 'Merged from: ${toMerge.map((i) => i.name).join(', ')}',
        createdAt: now,
        updatedAt: now,
        currency: resolveSharedCurrency(
          toMerge.map((i) => i.currency),
          ref.read(currencyCodeProvider),
        ),
        startDate: earliestStart,
        maturityDate: latestMaturity,
        expectedRate: firstSet((i) => i.expectedRate),
        incomeFrequency: firstSet((i) => i.incomeFrequency),
        platform: firstSet((i) => i.platform),
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
              currency: cf.currency,
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

  /// The latest live dated valuation of [investmentId] in [currency], or null
  /// when there is none or the feature is off.
  Future<InvestmentValuationSnapshot?> _mirrorInCurrency(
    String investmentId,
    String currency,
  ) async {
    if (!ref.read(valuationSnapshotsActiveProvider)) return null;
    // mirrorOf leaves out the cleared ones.
    return ValuationSnapshotSelector.mirrorOf(
      await ref.read(valuationRepositoryProvider).getByInvestment(investmentId),
      investmentId: investmentId,
      currency: currency,
    );
  }

  /// The live dated valuations of [investmentId], keyed by its id, or null
  /// while the feature is off (it is then valued exactly as before).
  ///
  /// One awaited server-first read per saved INCOME or RETURN, and only while
  /// the feature is on. INV-11 (A26) moves the milestone check to cached
  /// provider state, or off the save path, and this read goes with it.
  Future<Map<String, List<InvestmentValuationSnapshot>>?>
  _liveValuationSnapshotsOf(String investmentId) async {
    if (!ref.read(valuationSnapshotsActiveProvider)) return null;
    final snapshots = await ref
        .read(valuationRepositoryProvider)
        .getByInvestment(investmentId);
    return {
      investmentId: [
        for (final s in snapshots)
          if (s.isLive) s,
      ],
    };
  }

  /// The live dated valuations by investment id, or null while the feature
  /// is off: goal progress then values investments exactly as before.
  Future<Map<String, List<InvestmentValuationSnapshot>>?>
  _valuationSnapshotsByInvestment() async {
    if (!ref.read(valuationSnapshotsActiveProvider)) return null;
    final byInvestment = <String, List<InvestmentValuationSnapshot>>{};
    for (final s in await ref.read(valuationRepositoryProvider).getAll()) {
      if (s.isLive) byInvestment.putIfAbsent(s.investmentId, () => []).add(s);
    }
    return byInvestment;
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

  /// Returns [currency] if it is not blank. Stored data can carry a blank
  /// currency; it fails visibly here and is never defaulted (money rule 1).
  /// Throws [ValidationException] for a blank currency.
  String _requireCurrency(String currency) {
    if (currency.trim().isEmpty) {
      throw ValidationException(
        userMessage: 'Choose a currency for this amount.',
        technicalMessage: 'Validation failed: currency is blank',
      );
    }
    return currency;
  }

  /// Validates amount for cash flows.
  /// Throws [ValidationException] if amount is not positive.
  void _validateAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
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

  /// Validates the "Custom type" text of an investment of type Other.
  /// Throws [ValidationException] if it exceeds the maximum length.
  void _validateCustomTypeLabel(InvestmentType type, String? label) {
    if (type != InvestmentType.other) return;
    if (CustomTypeLabel.exceedsMaxLength(CustomTypeLabel.clean(label))) {
      throw ValidationException.tooLong(
        'Custom type',
        CustomTypeLabel.maxLength,
      );
    }
  }

  /// What [type] and the text typed in the "Custom type" field leave the
  /// investment storing (#936): nothing for a built-in type or blank text;
  /// otherwise a link to the matching active reusable type, or a label for
  /// this investment only. [existing] is the stored investment on an edit:
  /// text equal to its label keeps its link as it is. The saved types are
  /// read only when there is text to match.
  Future<CustomTypeLink> _resolveCustomType(
    InvestmentType type,
    String? typed, {
    InvestmentEntity? existing,
  }) async {
    if (type != InvestmentType.other) return CustomTypeLink.none;
    final label = CustomTypeLabel.clean(typed);
    if (label.isEmpty) return CustomTypeLink.none;
    final stored = existing?.type == InvestmentType.other ? existing : null;
    final unchanged = stored?.customTypeLabel == label;
    var saved = const <CustomInvestmentType>[];
    if (!unchanged) {
      try {
        saved = await ref.read(customInvestmentTypeRepositoryProvider).getAll();
      } catch (_) {
        // The saved types cannot be read (offline with an empty cache, or a
        // store error). The investment still saves, with the label for
        // itself only: losing the link is better than refusing the save.
      }
    }
    return CustomTypeCatalog.resolveForInvestment(
      saved,
      label,
      existingId: stored?.customTypeId,
      existingLabel: stored?.customTypeLabel,
    );
  }

  // ============ Reminder Helpers ============

  /// Schedules the income and maturity reminders of [investment], given as
  /// it is after the change, when it is open and not archived and has the
  /// field set; cancels them otherwise. A closed or archived investment
  /// never gets reminders.
  Future<void> _syncReminders(InvestmentEntity investment) async {
    final active = investment.isOpen && !investment.isArchived;
    if (active && investment.incomeFrequency != null) {
      await _scheduleIncomeReminder(investment);
    } else {
      await _cancelIncomeReminder(investment.id);
    }
    if (active && investment.maturityDate != null) {
      await _scheduleMaturityReminders(investment);
    } else {
      await _cancelMaturityReminders(investment.id);
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
            // Same anchor as the notification sync, so both give one date.
            lastIncomeDate:
                lastIncomeDate ?? investment.startDate ?? investment.createdAt,
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
  ///
  /// The MOIC is the one the screens show: the shared calculation's, on
  /// paid-in capital, from the cash flows and the current value of an open
  /// investment, all in the base currency (money rules 2, 3 and 4).
  Future<void> _checkMilestoneAfterCashFlow(String investmentId) async {
    try {
      final investment = await ref
          .read(investmentRepositoryProvider)
          .getInvestmentById(investmentId);
      if (investment == null) return;

      final cashFlows = await ref
          .read(investmentRepositoryProvider)
          .getCashFlowsByInvestment(investmentId);

      // Stats in the base currency: raw sums of mixed currencies would fire
      // false milestones and be shown under the wrong symbol. Without a
      // converter (signed out) there is no milestone to show. If a rate is
      // unavailable, throwError skips the check until the next cash flow;
      // the default fallback would keep the unconverted amount.
      final engine = ref.read(calculationEngineProvider);
      if (!engine.currency.isAvailable) return;
      final baseCurrency = ref.read(currencyCodeProvider);
      final converted = await engine.currency.batchConvert(
        cashFlows: cashFlows,
        baseCurrency: baseCurrency,
        fallbackStrategy: ConversionFallbackStrategy.throwError,
      );

      // An open investment is also worth what it is worth today. Its value is
      // worked out from the unconverted flows, then converted like them.
      final values = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: cashFlows,
        asOf: ref.read(valuationDateProvider),
        snapshots: await _liveValuationSnapshotsOf(investmentId),
      );
      final convertedValues = values.flows.isEmpty
          ? values
          : values.withConvertedFlows(
              await engine.currency.batchConvert(
                cashFlows: values.flows,
                baseCurrency: baseCurrency,
                fallbackStrategy: ConversionFallbackStrategy.throwError,
              ),
            );

      final stats = engine.financial.calculateStats(
        converted,
        includeXirr: false,
        terminalValues: convertedValues,
      );
      // No current value, or no known cost, means no MOIC: nothing to
      // announce.
      if (stats.needsCurrentValue || !stats.returnsKnown) return;

      // Check for milestone notification
      await ref
          .read(notificationServiceProvider)
          .checkAndShowMilestone(
            investmentId: investmentId,
            investmentName: investment.name,
            moic: stats.moic,
            gain: stats.gain,
            currency: baseCurrency,
          );
    } catch (e) {
      // Don't fail the main operation if milestone check fails
    }
  }

  /// Check for goal milestone achievements after adding a cash flow
  ///
  /// BUG FIX: Only check milestone if progress increased significantly (>0.5%)
  /// to avoid spamming notifications on every single cashflow addition.
  /// [newCashFlowId] is the cash flow just saved; progress without it is
  /// the progress before it.
  Future<void> _checkGoalMilestonesAfterCashFlow(String newCashFlowId) async {
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
      final cashFlowsBefore = cashFlows
          .where((c) => c.id != newCashFlowId)
          .toList();

      final notificationService = ref.read(notificationServiceProvider);

      // Progress in the base currency, as the Goals screen shows it; raw sums
      // of mixed currencies would announce the wrong milestones. Without a
      // rate, throwError skips that goal's amount-based alerts rather than
      // use unconverted amounts; other goals are still checked.
      final batchConverter = ref.read(batchCurrencyConverterProvider);
      final baseCurrency = ref.read(currencyCodeProvider);
      final snapshots = await _valuationSnapshotsByInvestment();

      // Check each goal for milestone achievements and alerts
      for (final goal in goals) {
        // Check for stale goals (no activity for X days). It needs no
        // amounts, so it runs even when a rate is unavailable.
        // This has built-in rate limiting (once per month)
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

        if (batchConverter == null) continue;
        final GoalProgress progress;
        final double targetInBase;
        final double previousPercent;
        try {
          progress = await GoalProgressCalculator.calculateMultiCurrency(
            goal: goal,
            allInvestments: investments,
            allCashFlows: cashFlows,
            batchConverter: batchConverter,
            baseCurrency: baseCurrency,
            fallbackStrategy: ConversionFallbackStrategy.throwError,
            snapshots: snapshots,
          );
          targetInBase = await GoalProgressCalculator.targetInBaseCurrency(
            goal: goal,
            batchConverter: batchConverter,
            baseCurrency: baseCurrency,
            fallbackStrategy: ConversionFallbackStrategy.throwError,
          );
          previousPercent =
              (await GoalProgressCalculator.calculateMultiCurrency(
                goal: goal,
                allInvestments: investments,
                allCashFlows: cashFlowsBefore,
                batchConverter: batchConverter,
                baseCurrency: baseCurrency,
                fallbackStrategy: ConversionFallbackStrategy.throwError,
                snapshots: snapshots,
              )).progressPercent;
        } on CurrencyConversionException {
          continue;
        }

        final currentPercent = progress.progressPercent;

        // Check if we should notify about milestone achievements
        // This handles both boundary proximity AND crossed milestones
        final shouldCheckMilestone = _shouldCheckGoalMilestone(
          currentPercent: currentPercent,
          previousPercent: previousPercent,
        );

        if (shouldCheckMilestone) {
          // Check for milestone achievements
          await notificationService.checkAndShowGoalMilestone(
            goalId: goal.id,
            goalName: goal.name,
            progressPercent: currentPercent,
            currentValue: progress.currentAmount,
            targetValue: targetInBase,
            currency: baseCurrency,
            // Only a milestone this cash flow crossed is announced; ones
            // the goal had passed before it are recorded silently.
            announce: _crossedGoalMilestone(previousPercent, currentPercent),
          );
        }

        // Check for at-risk goals (status is behind)
        // Only check once per week to avoid spam
        if (progress.status == GoalStatus.behind) {
          await notificationService.showGoalAtRiskNotification(
            goalId: goal.id,
            goalName: goal.name,
            progressPercent: currentPercent,
            targetDate: goal.targetDate,
            projectedDate: progress.projectedCompletionDate,
          );
        }
      }
    } catch (e) {
      // Don't fail the main operation if goal milestone check fails
      // Error logged in debug mode
    }
  }

  /// Determine if we should check for goal milestones based on current progress
  ///
  /// CodeRabbit fix: Detects both boundary proximity AND milestone crossings.
  /// This prevents both:
  /// 1. Unnecessary checks when far from milestones (anti-spam)
  /// 2. Missing milestones when jumping past them (e.g., 22% → 30% should trigger 25%)
  ///
  /// Returns true if:
  /// - Progress is within 2% of a milestone (e.g., 23-27% for 25% milestone)
  /// - Progress crossed a milestone since last check (e.g., was 22%, now 30%)
  /// - Progress is past 98% (approaching 100% completion)
  bool _shouldCheckGoalMilestone({
    required double currentPercent,
    double? previousPercent,
  }) {
    const threshold = 2.0; // Check if within 2% of milestone

    // Check if we're close to any milestone OR crossed one
    for (final milestone in _goalMilestones) {
      // Near boundary check (original logic)
      final isNearBoundary =
          currentPercent >= milestone - threshold &&
          currentPercent <= milestone + threshold;

      // CodeRabbit fix: Detect milestone crossing even when jumping past
      // Example: was 22%, now 30% → should trigger 25% notification
      final crossedSinceLast =
          previousPercent != null &&
          previousPercent < milestone &&
          currentPercent >= milestone;

      if (isNearBoundary || crossedSinceLast) {
        return true; // Either near milestone or crossed it
      }
    }

    // Always check if very close to completion (>98%)
    if (currentPercent >= 98.0) {
      return true;
    }

    return false; // Far from any milestone and didn't cross any, skip check
  }

  /// Whether progress went from below a milestone to at or above it.
  static bool _crossedGoalMilestone(double before, double after) =>
      _goalMilestones.any((m) => before < m && after >= m);
}
