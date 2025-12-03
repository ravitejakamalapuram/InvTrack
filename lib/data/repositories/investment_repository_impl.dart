import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/domain/entities/investment.dart' as domain;
import 'package:inv_tracker/domain/repositories/investment_repository.dart';
import 'package:uuid/uuid.dart';

/// Implementation of InvestmentRepository using Drift database.
class InvestmentRepositoryImpl implements InvestmentRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  InvestmentRepositoryImpl(this._db);

  @override
  Future<List<domain.Investment>> getAll({SortOrder sort = SortOrder.nameAsc}) async {
    final query = _db.select(_db.investments)
      ..where((t) => t.isDeleted.equals(false));

    switch (sort) {
      case SortOrder.nameAsc:
        query.orderBy([(t) => OrderingTerm.asc(t.name)]);
      case SortOrder.nameDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.name)]);
      case SortOrder.dateAsc:
        query.orderBy([(t) => OrderingTerm.asc(t.startDate)]);
      case SortOrder.dateDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.startDate)]);
      case SortOrder.createdAsc:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case SortOrder.createdDesc:
        query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    }

    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<domain.Investment>> watchAll() {
    final query = _db.select(_db.investments)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<domain.Investment?> getById(String id) async {
    final row = await (_db.select(_db.investments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<domain.Investment> create(domain.Investment investment) async {
    final now = DateTime.now();
    final id = investment.id.isEmpty ? _uuid.v4() : investment.id;

    final companion = InvestmentsCompanion.insert(
      id: id,
      name: investment.name,
      category: investment.category,
      startDate: investment.startDate,
      notes: Value(investment.notes),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.investments).insert(companion);
    await _addToSyncQueue('create', 'investments', id, investment);

    return investment.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  @override
  Future<domain.Investment> update(domain.Investment investment) async {
    final now = DateTime.now();

    await (_db.update(_db.investments)..where((t) => t.id.equals(investment.id)))
        .write(InvestmentsCompanion(
      name: Value(investment.name),
      category: Value(investment.category),
      startDate: Value(investment.startDate),
      notes: Value(investment.notes),
      updatedAt: Value(now),
      isSynced: const Value(false),
    ));

    await _addToSyncQueue('update', 'investments', investment.id, investment);

    return investment.copyWith(updatedAt: now, isSynced: false);
  }

  @override
  Future<void> delete(String id) async {
    await (_db.update(_db.investments)..where((t) => t.id.equals(id)))
        .write(const InvestmentsCompanion(
      isDeleted: Value(true),
      isSynced: Value(false),
    ));
    await _addToSyncQueue('delete', 'investments', id, null);
  }

  @override
  Future<void> hardDelete(String id) async {
    await (_db.delete(_db.investments)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<domain.Investment>> searchByName(String query) async {
    final rows = await (_db.select(_db.investments)
          ..where((t) => t.isDeleted.equals(false) & t.name.contains(query)))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.Investment>> getByCategory(String category) async {
    final rows = await (_db.select(_db.investments)
          ..where((t) => t.isDeleted.equals(false) & t.category.equals(category)))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> count() async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) as count FROM investments WHERE is_deleted = 0',
    ).getSingle();
    return result.read<int>('count');
  }

  @override
  Future<List<domain.Investment>> getUnsynced() async {
    final rows = await (_db.select(_db.investments)
          ..where((t) => t.isSynced.equals(false)))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> markSynced(String id) async {
    await (_db.update(_db.investments)..where((t) => t.id.equals(id)))
        .write(const InvestmentsCompanion(isSynced: Value(true)));
  }

  domain.Investment _toDomain(Investment row) {
    return domain.Investment(
      id: row.id,
      name: row.name,
      category: row.category,
      startDate: row.startDate,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
      isDeleted: row.isDeleted,
    );
  }

  Future<void> _addToSyncQueue(String op, String table, String id, domain.Investment? inv) async {
    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
      operation: op,
      targetTable: table,
      recordId: id,
      payload: inv != null ? jsonEncode(_investmentToJson(inv)) : '{}',
      createdAt: DateTime.now(),
    ));
  }

  Map<String, dynamic> _investmentToJson(domain.Investment inv) => {
    'id': inv.id, 'name': inv.name, 'category': inv.category,
    'startDate': inv.startDate.toIso8601String(), 'notes': inv.notes,
  };
}

