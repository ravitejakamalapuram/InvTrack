/// Stream-based providers for investments and cash flows.
/// These are the single source of truth - all other providers derive from these.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

// Re-export entities for convenience
export 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
export 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

// Re-export auth state for convenience
export 'package:inv_tracker/core/di/database_module.dart' show isAuthenticatedProvider;

// ============ INVESTMENT STREAM PROVIDERS ============

/// Watch all investments (reactive).
/// Returns empty list if user is not authenticated.
final allInvestmentsProvider = StreamProvider<List<InvestmentEntity>>((ref) {
  try {
    return ref.watch(investmentRepositoryProvider).watchAllInvestments();
  } on AuthException {
    return Stream.value([]);
  }
});

/// Watch investments by status.
/// Returns empty list if user is not authenticated.
final investmentsByStatusProvider =
    StreamProvider.family<List<InvestmentEntity>, InvestmentStatus>((ref, status) {
  try {
    return ref.watch(investmentRepositoryProvider).watchInvestmentsByStatus(status);
  } on AuthException {
    return Stream.value([]);
  }
});

/// Get a single investment by ID.
/// Returns null if user is not authenticated.
final investmentByIdProvider = FutureProvider.family<InvestmentEntity?, String>((ref, id) async {
  try {
    return ref.watch(investmentRepositoryProvider).getInvestmentById(id);
  } on AuthException {
    return null;
  }
});

// ============ CASH FLOW STREAM PROVIDERS ============

/// Watch cash flows for an investment (reactive).
/// Returns empty list if user is not authenticated.
final cashFlowsByInvestmentProvider =
    StreamProvider.family<List<CashFlowEntity>, String>((ref, investmentId) {
  try {
    return ref.watch(investmentRepositoryProvider).watchCashFlowsByInvestment(investmentId);
  } on AuthException {
    return Stream.value([]);
  }
});

/// Watch all cash flows (reactive stream - single source of truth).
/// Returns empty list if user is not authenticated.
final allCashFlowsStreamProvider = StreamProvider<List<CashFlowEntity>>((ref) {
  try {
    return ref.watch(investmentRepositoryProvider).watchAllCashFlows();
  } on AuthException {
    return Stream.value([]);
  }
});

/// Filtered cash flows for valid investments only (derived from streams)
/// This is the SINGLE SOURCE OF TRUTH for all stats calculations
final validCashFlowsProvider = Provider<AsyncValue<List<CashFlowEntity>>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

  return investmentsAsync.when(
    data: (investments) {
      final validIds = investments.map((i) => i.id).toSet();
      return cashFlowsAsync.when(
        data: (cashFlows) => AsyncValue.data(
          cashFlows.where((cf) => validIds.contains(cf.investmentId)).toList(),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

