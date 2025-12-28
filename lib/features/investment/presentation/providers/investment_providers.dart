/// Stream-based providers for investments and cash flows.
/// These are the single source of truth - all other providers derive from these.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

// Re-export entities for convenience
export 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
export 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

// Re-export auth state for convenience
export 'package:inv_tracker/core/di/database_module.dart'
    show isAuthenticatedProvider;

// ============ INVESTMENT STREAM PROVIDERS ============

/// Watch all investments (reactive).
/// Returns empty list if user is not authenticated.
final allInvestmentsProvider = StreamProvider<List<InvestmentEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(investmentRepositoryProvider).watchAllInvestments();
});

/// Watch investments by status.
/// Returns empty list if user is not authenticated.
final investmentsByStatusProvider =
    StreamProvider.family<List<InvestmentEntity>, InvestmentStatus>((
      ref,
      status,
    ) {
      // Check auth first to avoid exception when user signs out
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      return ref
          .watch(investmentRepositoryProvider)
          .watchInvestmentsByStatus(status);
    });

/// Get a single investment by ID.
/// Returns null if user is not authenticated.
final investmentByIdProvider = FutureProvider.family<InvestmentEntity?, String>(
  (ref, id) async {
    // Check auth first to avoid exception when user signs out
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (!isAuthenticated) {
      return null;
    }
    return ref.watch(investmentRepositoryProvider).getInvestmentById(id);
  },
);

// ============ CASH FLOW STREAM PROVIDERS ============

/// Watch cash flows for an investment (reactive).
/// Returns empty list if user is not authenticated.
final cashFlowsByInvestmentProvider =
    StreamProvider.family<List<CashFlowEntity>, String>((ref, investmentId) {
      // Check auth first to avoid exception when user signs out
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      return ref
          .watch(investmentRepositoryProvider)
          .watchCashFlowsByInvestment(investmentId);
    });

/// Watch all cash flows (reactive stream - single source of truth).
/// Returns empty list if user is not authenticated.
final allCashFlowsStreamProvider = StreamProvider<List<CashFlowEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(investmentRepositoryProvider).watchAllCashFlows();
});

/// Active (non-archived) investments only.
/// With separate collections, allInvestmentsProvider already returns only active investments.
/// This provider is kept for backward compatibility.
final activeInvestmentsProvider = Provider<AsyncValue<List<InvestmentEntity>>>((
  ref,
) {
  return ref.watch(allInvestmentsProvider);
});

// ============ ARCHIVED INVESTMENT STREAM PROVIDERS ============

/// Watch all archived investments (reactive).
/// Returns empty list if user is not authenticated.
final archivedInvestmentsProvider = StreamProvider<List<InvestmentEntity>>((
  ref,
) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(investmentRepositoryProvider).watchArchivedInvestments();
});

/// Watch archived cash flows for an investment (reactive).
/// Returns empty list if user is not authenticated.
final archivedCashFlowsByInvestmentProvider =
    StreamProvider.family<List<CashFlowEntity>, String>((ref, investmentId) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      return ref
          .watch(investmentRepositoryProvider)
          .watchArchivedCashFlowsByInvestment(investmentId);
    });

/// Filtered cash flows for valid investments only (derived from streams)
/// This is the SINGLE SOURCE OF TRUTH for all stats calculations.
/// IMPORTANT: Only includes cash flows from NON-ARCHIVED investments.
final validCashFlowsProvider = Provider<AsyncValue<List<CashFlowEntity>>>((
  ref,
) {
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

  return investmentsAsync.when(
    data: (investments) {
      // Only include cash flows from active (non-archived) investments
      final activeIds = investments.map((i) => i.id).toSet();
      return cashFlowsAsync.when(
        data: (cashFlows) => AsyncValue.data(
          cashFlows.where((cf) => activeIds.contains(cf.investmentId)).toList(),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
