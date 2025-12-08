import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/database/app_database.dart';

import 'package:inv_tracker/features/investment/data/repositories/investment_repository_impl.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:inv_tracker/features/sync/domain/repositories/sync_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestmentRepositoryImpl(db);
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncRepositoryImpl(db);
});
