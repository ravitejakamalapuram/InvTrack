import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:uuid/uuid.dart';

final allPortfoliosProvider = StreamProvider<List<PortfolioEntity>>((ref) {
  return ref.watch(portfolioRepositoryProvider).watchAllPortfolios();
});

final portfolioProvider = StateNotifierProvider<PortfolioNotifier, AsyncValue<void>>((ref) {
  return PortfolioNotifier(ref);
});

class PortfolioNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  PortfolioNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> createDefaultPortfolioIfNone() async {
    final portfolios = await _ref.read(portfolioRepositoryProvider).getAllPortfolios();
    if (portfolios.isEmpty) {
      await createPortfolio(name: 'Main Portfolio', currency: 'USD');
    }
  }

  Future<void> createPortfolio({required String name, required String currency}) async {
    state = const AsyncValue.loading();
    try {
      final portfolio = PortfolioEntity(
        id: const Uuid().v4(),
        name: name,
        currency: currency,
        createdAt: DateTime.now(),
      );
      await _ref.read(portfolioRepositoryProvider).createPortfolio(portfolio);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
