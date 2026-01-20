/// Providers for document management.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

// Re-export document entity for convenience
export 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

/// Watch documents for an investment (reactive stream)
/// Returns empty list if user is not authenticated
final documentsByInvestmentProvider =
    StreamProvider.family<List<DocumentEntity>, String>((ref, investmentId) {
      final isAuthenticated = ref.watch(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return Stream.value([]);
      }
      return ref
          .watch(documentRepositoryProvider)
          .watchDocumentsByInvestment(investmentId)
          .handleError((error, stackTrace) {
            debugPrint('documentsByInvestmentProvider: ERROR - $error');
          });
    });

/// Get document count for an investment
final documentCountProvider = FutureProvider.family<int, String>((
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
final documentByIdProvider = FutureProvider.family<DocumentEntity?, String>((
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
final totalDocumentStorageProvider = FutureProvider<int>((ref) async {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return 0;
  }
  return ref.watch(documentStorageServiceProvider).getTotalStorageUsed();
});
