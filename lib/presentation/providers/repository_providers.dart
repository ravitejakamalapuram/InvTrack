import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/data/repositories/entry_repository_impl.dart';
import 'package:inv_tracker/data/repositories/investment_repository_impl.dart';
import 'package:inv_tracker/domain/entities/entry.dart';
import 'package:inv_tracker/domain/entities/investment.dart';
import 'package:inv_tracker/domain/repositories/entry_repository.dart';
import 'package:inv_tracker/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/presentation/providers/database_provider.dart';

/// Provider for InvestmentRepository.
final investmentRepositoryProvider = Provider<InvestmentRepository?>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  final db = dbAsync.valueOrNull;
  if (db == null) return null;
  return InvestmentRepositoryImpl(db);
});

/// Provider for EntryRepository.
final entryRepositoryProvider = Provider<EntryRepository?>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  final db = dbAsync.valueOrNull;
  if (db == null) return null;
  return EntryRepositoryImpl(db);
});

/// Provider for watching all investments.
final investmentsProvider = StreamProvider<List<Investment>>((ref) {
  final repo = ref.watch(investmentRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchAll();
});

/// Provider for getting entries for a specific investment.
final entriesProvider = StreamProvider.family<List<Entry>, String>((ref, investmentId) {
  final repo = ref.watch(entryRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchByInvestmentId(investmentId);
});

/// Provider for investment count.
final investmentCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(investmentRepositoryProvider);
  if (repo == null) return 0;
  return repo.count();
});

/// Provider for total invested amount for an investment.
final totalInvestedProvider = FutureProvider.family<double, String>((ref, investmentId) async {
  final repo = ref.watch(entryRepositoryProvider);
  if (repo == null) return 0;
  return repo.getTotalInvested(investmentId);
});

/// Provider for total withdrawn amount for an investment.
final totalWithdrawnProvider = FutureProvider.family<double, String>((ref, investmentId) async {
  final repo = ref.watch(entryRepositoryProvider);
  if (repo == null) return 0;
  return repo.getTotalWithdrawn(investmentId);
});

