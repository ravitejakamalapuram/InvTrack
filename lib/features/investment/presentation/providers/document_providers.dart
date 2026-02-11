/// Providers for document management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

// Re-export document entity for convenience
export 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

/// Watch documents for an investment (reactive stream)
/// Returns empty list if user is not authenticated
/// Errors propagate to UI for proper error state display
/// Uses .autoDispose.family to prevent memory leaks from cached instances
final documentsByInvestmentProvider =
    StreamProvider.autoDispose.family<List<DocumentEntity>, String>((ref, investmentId) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      // Let errors propagate to UI - document widgets handle AsyncValue.error properly
      return ref
          .watch(documentRepositoryProvider)
          .watchDocumentsByInvestment(investmentId);
    });

/// Get document count for an investment
/// Uses .autoDispose.family to prevent memory leaks from cached instances
final documentCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  investmentId,
) async {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return 0;
  }
  return ref.watch(documentRepositoryProvider).getDocumentCount(investmentId);
});

/// Get a single document by ID
/// Uses .autoDispose.family to prevent memory leaks from cached instances
final documentByIdProvider = FutureProvider.autoDispose.family<DocumentEntity?, String>((
  ref,
  documentId,
) async {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return null;
  }
  return ref.watch(documentRepositoryProvider).getDocumentById(documentId);
});

/// Get total storage used by all documents
/// Uses .autoDispose for one-time fetch that should be disposed when not needed
final totalDocumentStorageProvider = FutureProvider.autoDispose<int>((ref) async {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return 0;
  }
  return ref.watch(documentStorageServiceProvider).getTotalStorageUsed();
});
