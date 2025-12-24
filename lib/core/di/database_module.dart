import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Provider for FirebaseFirestore instance with offline persistence enabled
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;

  // Enable offline persistence (enabled by default on mobile, explicit for web)
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  return firestore;
});

/// Provider that exposes whether the user is authenticated
/// Used by UI to show appropriate prompts without triggering errors
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  return user != null;
});

/// Provider for the investment repository using Firestore
/// Throws AuthException.notAuthenticated if user is not authenticated
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  // Get user ID from auth state
  final user = authState.valueOrNull;
  if (user == null) {
    // Throw a specific exception that UI can catch and handle gracefully
    throw AuthException.notAuthenticated();
  }

  return FirestoreInvestmentRepository(
    firestore: firestore,
    userId: user.id,
  );
});
