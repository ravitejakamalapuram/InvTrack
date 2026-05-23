/// Expected Cash Flow Provider
///
/// Provides expected cash flow data (future placeholder - will be implemented
/// with Firestore persistence in Phase 2)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

/// Provider for expected cash flows
/// 
/// Phase 1: Returns empty list (core logic in services)
/// Phase 2: Will query Firestore for persisted expectations
final expectedCashFlowsProvider = FutureProvider.autoDispose<List<ExpectedCashFlowEntity>>((ref) async {
  // Placeholder: Return empty list
  // In Phase 2, this will query Firestore:
  // return await ref.watch(expectedCashFlowRepositoryProvider).getAllExpectedCashFlows();
  return [];
});
