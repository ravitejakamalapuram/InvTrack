import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/app_database.dart';

import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/repositories/portfolio_repository.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  final AppDatabase _db;

  PortfolioRepositoryImpl(this._db);

  @override
  Stream<List<PortfolioEntity>> watchAllPortfolios() {
    return _db.select(_db.portfolios).watch().map((rows) {
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<List<PortfolioEntity>> getAllPortfolios() async {
    final rows = await _db.select(_db.portfolios).get();
    return rows.map(_mapRowToEntity).toList();
  }

  @override
  Future<PortfolioEntity?> getPortfolioById(String id) async {
    final row = await (_db.select(_db.portfolios)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    return row != null ? _mapRowToEntity(row) : null;
  }

  @override
  Future<void> createPortfolio(PortfolioEntity portfolio) async {
    await _db.into(_db.portfolios).insert(
          PortfoliosCompanion(
            id: Value(portfolio.id),
            name: Value(portfolio.name),
            currency: Value(portfolio.currency),
            createdAt: Value(portfolio.createdAt),
          ),
        );
  }

  @override
  Future<void> updatePortfolio(PortfolioEntity portfolio) async {
    await (_db.update(_db.portfolios)..where((tbl) => tbl.id.equals(portfolio.id))).write(
      PortfoliosCompanion(
        name: Value(portfolio.name),
        currency: Value(portfolio.currency),
      ),
    );
  }

  @override
  Future<void> deletePortfolio(String id) async {
    await (_db.delete(_db.portfolios)..where((tbl) => tbl.id.equals(id))).go();
  }

  PortfolioEntity _mapRowToEntity(Portfolio row) {
    return PortfolioEntity(
      id: row.id,
      name: row.name,
      currency: row.currency,
      createdAt: row.createdAt,
    );
  }
}
