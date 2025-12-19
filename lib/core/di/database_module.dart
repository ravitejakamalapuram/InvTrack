import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Provider for the investment repository using Firestore
/// Returns null if user is not authenticated (guest mode uses local-only)
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  // Get user ID from auth state
  final user = authState.valueOrNull;
  if (user == null || user.isGuest) {
    // For guest users, we'll throw an error - they need to sign in for cloud sync
    throw Exception('User must be signed in to access investments');
  }

  return FirestoreInvestmentRepository(
    firestore: firestore,
    userId: user.id,
  );
});
