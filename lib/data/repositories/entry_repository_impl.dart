import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/domain/entities/entry.dart' as domain;
import 'package:inv_tracker/domain/repositories/entry_repository.dart';
import 'package:uuid/uuid.dart';

/// Implementation of EntryRepository using Drift database.
class EntryRepositoryImpl implements EntryRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  EntryRepositoryImpl(this._db);

  @override
  Future<List<domain.Entry>> getByInvestmentId(String investmentId) async {
    final rows = await (_db.select(_db.entries)
          ..where((t) => t.investmentId.equals(investmentId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<domain.Entry>> watchByInvestmentId(String investmentId) {
    final query = _db.select(_db.entries)
      ..where((t) => t.investmentId.equals(investmentId))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<domain.Entry>> getAll() async {
    final rows = await (_db.select(_db.entries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<domain.Entry?> getById(String id) async {
    final row = await (_db.select(_db.entries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<domain.Entry> create(domain.Entry entry) async {
    final now = DateTime.now();
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;

    final companion = EntriesCompanion.insert(
      id: id,
      investmentId: entry.investmentId,
      date: entry.date,
      type: entry.type.name,
      amount: entry.amount,
      units: Value(entry.units),
      pricePerUnit: Value(entry.pricePerUnit),
      note: Value(entry.note),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.entries).insert(companion);
    await _addToSyncQueue('create', 'entries', id, entry);

    return entry.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  @override
  Future<domain.Entry> update(domain.Entry entry) async {
    final now = DateTime.now();

    await (_db.update(_db.entries)..where((t) => t.id.equals(entry.id)))
        .write(EntriesCompanion(
      date: Value(entry.date),
      type: Value(entry.type.name),
      amount: Value(entry.amount),
      units: Value(entry.units),
      pricePerUnit: Value(entry.pricePerUnit),
      note: Value(entry.note),
      updatedAt: Value(now),
      isSynced: const Value(false),
    ));

    await _addToSyncQueue('update', 'entries', entry.id, entry);
    return entry.copyWith(updatedAt: now, isSynced: false);
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();
    await _addToSyncQueue('delete', 'entries', id, null);
  }

  @override
  Future<void> deleteByInvestmentId(String investmentId) async {
    await (_db.delete(_db.entries)..where((t) => t.investmentId.equals(investmentId))).go();
  }

  @override
  Future<List<domain.Entry>> getByDateRange(String investmentId, DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.entries)
          ..where((t) => t.investmentId.equals(investmentId) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.Entry>> getByType(domain.EntryType type) async {
    final rows = await (_db.select(_db.entries)..where((t) => t.type.equals(type.name))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> countByInvestmentId(String investmentId) async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) as count FROM entries WHERE investment_id = ?',
      variables: [Variable.withString(investmentId)],
    ).getSingle();
    return result.read<int>('count');
  }

  @override
  Future<double> getTotalInvested(String investmentId) async {
    final result = await _db.customSelect(
      "SELECT COALESCE(SUM(amount), 0) as total FROM entries WHERE investment_id = ? AND type = 'inflow'",
      variables: [Variable.withString(investmentId)],
    ).getSingle();
    return result.read<double>('total');
  }

  @override
  Future<double> getTotalWithdrawn(String investmentId) async {
    final result = await _db.customSelect(
      "SELECT COALESCE(SUM(amount), 0) as total FROM entries WHERE investment_id = ? AND type = 'outflow'",
      variables: [Variable.withString(investmentId)],
    ).getSingle();
    return result.read<double>('total');
  }

  @override
  Future<List<domain.Entry>> getUnsynced() async {
    final rows = await (_db.select(_db.entries)..where((t) => t.isSynced.equals(false))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> markSynced(String id) async {
    await (_db.update(_db.entries)..where((t) => t.id.equals(id)))
        .write(const EntriesCompanion(isSynced: Value(true)));
  }

  domain.Entry _toDomain(Entry row) {
    return domain.Entry(
      id: row.id, investmentId: row.investmentId,
      type: domain.EntryType.fromString(row.type),
      amount: row.amount, units: row.units, pricePerUnit: row.pricePerUnit,
      date: row.date, note: row.note,
      createdAt: row.createdAt, updatedAt: row.updatedAt, isSynced: row.isSynced,
    );
  }

  Future<void> _addToSyncQueue(String op, String table, String id, domain.Entry? e) async {
    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
      operation: op, targetTable: table, recordId: id,
      payload: e != null ? jsonEncode({'id': e.id, 'investmentId': e.investmentId,
        'type': e.type.name, 'amount': e.amount, 'date': e.date.toIso8601String()}) : '{}',
      createdAt: DateTime.now(),
    ));
  }
}

