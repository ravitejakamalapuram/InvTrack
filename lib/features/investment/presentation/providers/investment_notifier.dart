/// State notifier for investment mutations (CRUD operations).
/// Handles all write operations for investments and cash flows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:uuid/uuid.dart';

// ============ INVESTMENT NOTIFIER (ACTIONS) ============

final investmentNotifierProvider =
    StateNotifierProvider<InvestmentNotifier, AsyncValue<void>>((ref) {
  return InvestmentNotifier(ref);
});

class InvestmentNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  InvestmentNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Create a new investment.
  /// Throws [ValidationException] if name is empty or exceeds max length.
  Future<InvestmentEntity> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
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
      );
      await _ref.read(investmentRepositoryProvider).createInvestment(investment);

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
  }) async {
    // Input validation
    _validateName(name);
    _validateNotes(notes);

    state = const AsyncValue.loading();
    try {
      final existing = await _ref.read(investmentRepositoryProvider).getInvestmentById(id);
      if (existing == null) throw DataException.notFound('Investment', id);

      final updated = existing.copyWith(
        name: name.trim(),
        type: type,
        notes: notes?.trim(),
        updatedAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).updateInvestment(updated);

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
      await _ref.read(investmentRepositoryProvider).closeInvestment(id);
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
      await _ref.read(investmentRepositoryProvider).reopenInvestment(id);
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
      await _ref.read(investmentRepositoryProvider).deleteInvestment(id);
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
      final deletedCount = await _ref
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
      );
      await _ref.read(investmentRepositoryProvider).addCashFlow(cashFlow);

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
      );
      await _ref.read(investmentRepositoryProvider).updateCashFlow(cashFlow);

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
      await _ref.read(investmentRepositoryProvider).deleteCashFlow(id);
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
      final repo = _ref.read(investmentRepositoryProvider);

      // Get all investments to merge
      final allInvestments = await _ref.read(allInvestmentsProvider.future);
      final toMerge = allInvestments.where((i) => investmentIds.contains(i.id)).toList();

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
        finalType = typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
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
          newCashFlows.add(CashFlowEntity(
            id: const Uuid().v4(),
            investmentId: newInvestmentId,
            type: cf.type,
            amount: cf.amount,
            date: cf.date,
            notes: cf.notes != null ? '${cf.notes} (from ${inv.name})' : 'From ${inv.name}',
            createdAt: now,
          ));
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
      final result = await _ref.read(investmentRepositoryProvider).bulkImport(
        investments: investments,
        cashFlows: cashFlows,
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
    _ref.invalidate(allInvestmentsProvider);
    _ref.invalidate(allCashFlowsStreamProvider);
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
      throw ValidationException.tooLong('Name', ValidationConstants.maxNameLength);
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
    if (notes != null && notes.trim().length > ValidationConstants.maxNotesLength) {
      throw ValidationException.tooLong('Notes', ValidationConstants.maxNotesLength);
    }
  }
}
