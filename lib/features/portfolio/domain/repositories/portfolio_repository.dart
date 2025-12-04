import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';

abstract class PortfolioRepository {
  Stream<List<PortfolioEntity>> watchAllPortfolios();
  Future<List<PortfolioEntity>> getAllPortfolios();
  Future<PortfolioEntity?> getPortfolioById(String id);
  Future<void> createPortfolio(PortfolioEntity portfolio);
  Future<void> updatePortfolio(PortfolioEntity portfolio);
  Future<void> deletePortfolio(String id);
}
