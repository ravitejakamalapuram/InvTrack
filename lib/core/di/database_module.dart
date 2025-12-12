import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/database/app_database.dart';

import 'package:inv_tracker/features/investment/data/repositories/investment_repository_impl.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Provider that holds the current user's ID for database isolation.
/// This is set when a user logs in (either Google or Guest).
final currentUserIdProvider = StateProvider<String?>((ref) => null);

/// Database provider that creates a user-specific database.
/// Each user gets their own isolated database file.
///
/// The database is recreated when [currentUserIdProvider] changes,
/// ensuring complete data isolation between users.
final databaseProvider = Provider<AppDatabase>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    // No user logged in - return a temporary database
    // This should rarely happen as auth should be resolved before accessing DB
    final database = AppDatabase();
    ref.onDispose(database.close);
    return database;
  }

  // Create user-specific database
  final database = AppDatabase.forUser(userId);
  ref.onDispose(database.close);
  return database;
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestmentRepositoryImpl(db);
});
