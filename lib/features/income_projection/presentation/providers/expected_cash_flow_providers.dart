/// Stream-based providers for expected cash flows.
/// These are the single source of truth for Income Guardian projections.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

// Re-export entities for convenience
export 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

// Re-export auth state for convenience
export 'package:inv_tracker/core/di/database_module.dart'
    show isAuthenticatedProvider;

// ============ INCOME CALENDAR STATE PROVIDERS ============

/// Filter options for income calendar
enum IncomeCalendarFilter {
  all,
  pending,
  overdue,
}

// Export for use in other files
export 'expected_cash_flow_providers.dart' show IncomeCalendarFilter;

/// Provider for current calendar filter
/// Returns the current filter state for the income calendar
final incomeCalendarFilterProvider = Provider.autoDispose<IncomeCalendarFilter>((ref) {
  return IncomeCalendarFilter.all;
});

/// Provider for current month offset (0 = current month, -1 = last month, +1 = next month)
/// Returns the current month offset
final incomeCalendarMonthOffsetProvider = Provider.autoDispose<int>((ref) {
  return 0;
});

// ============ EXPECTED CASH FLOW STREAM PROVIDERS ============

/// Watch all expected cash flows (reactive).
/// Returns empty list if user is not authenticated.
/// Errors propagate to UI for proper error handling with retry buttons.
final allExpectedCashFlowsProvider =
    StreamProvider<List<ExpectedCashFlowEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }

  // Let errors propagate to UI - screens handle AsyncValue.error properly
  return ref.watch(expectedCashFlowRepositoryProvider).watchAllExpectedCashFlows();
});

/// Watch expected cash flows for a specific investment (reactive).
/// Returns empty list if user is not authenticated.
/// Uses .autoDispose.family to prevent memory leaks from cached instances.
final expectedCashFlowsByInvestmentProvider = StreamProvider.autoDispose
    .family<List<ExpectedCashFlowEntity>, String>((ref, investmentId) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }

  // Let errors propagate to UI
  return ref
      .watch(expectedCashFlowRepositoryProvider)
      .watchExpectedCashFlowsByInvestment(investmentId);
});

/// Watch pending expected cash flows (reactive).
/// Returns only cash flows with status PENDING.
/// Returns empty list if user is not authenticated.
final pendingExpectedCashFlowsProvider =
    StreamProvider<List<ExpectedCashFlowEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }

  // Let errors propagate to UI
  return ref
      .watch(expectedCashFlowRepositoryProvider)
      .watchPendingExpectedCashFlows();
});

/// Watch overdue expected cash flows (reactive).
/// Returns only cash flows that are past their expected date and still PENDING.
/// Returns empty list if user is not authenticated.
final overdueExpectedCashFlowsProvider =
    StreamProvider<List<ExpectedCashFlowEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }

  // Let errors propagate to UI
  return ref
      .watch(expectedCashFlowRepositoryProvider)
      .watchOverdueExpectedCashFlows();
});

/// Watch upcoming expected cash flows (reactive).
/// Returns cash flows within next [days] days (default: 7).
/// Returns empty list if user is not authenticated.
/// Uses .family to allow different time windows.
final upcomingExpectedCashFlowsProvider =
    StreamProvider.family<List<ExpectedCashFlowEntity>, int>((ref, days) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }

  // Let errors propagate to UI
  return ref
      .watch(expectedCashFlowRepositoryProvider)
      .watchUpcomingExpectedCashFlows(days: days);
});

/// Get a single expected cash flow by ID.
/// Returns null if user is not authenticated.
final expectedCashFlowByIdProvider =
    FutureProvider.family<ExpectedCashFlowEntity?, String>(
  (ref, id) async {
    // Check auth first to avoid exception when user signs out
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (!isAuthenticated) {
      return null;
    }
    return ref
        .watch(expectedCashFlowRepositoryProvider)
        .getExpectedCashFlowById(id);
  },
);
