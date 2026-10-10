// A17 / GAP1-12: 'Recently Closed' was ranked by updatedAt, so an old closed
// item that was edited, archived or unarchived jumped above one closed last
// week. It is ranked by the day it was closed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_analytics_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

InvestmentEntity _closed(
  String id, {
  DateTime? closedAt,
  required DateTime updatedAt,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.closed,
  createdAt: DateTime(2023),
  updatedAt: updatedAt,
  closedAt: closedAt,
);

Future<List<String>> _recentIds(List<InvestmentEntity> investments) async {
  final container = ProviderContainer(
    overrides: [
      activeInvestmentsProvider.overrideWithValue(AsyncValue.data(investments)),
      convertedCashFlowsProvider.overrideWithValue(const AsyncValue.data([])),
    ],
  );
  addTearDown(container.dispose);
  final result = container.read(recentlyClosedInvestmentsProvider);
  return [for (final item in result.requireValue) item.investment.id];
}

void main() {
  test('an old item that was edited later does not jump to the top', () async {
    final ids = await _recentIds([
      // Closed in March 2024, renamed this week.
      _closed(
        'old',
        closedAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2026, 10, 2),
      ),
      // Closed last week.
      _closed(
        'recent',
        closedAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      ),
    ]);

    expect(ids, ['recent', 'old']);
  });

  test('keeps the three most recently closed, newest first', () async {
    final ids = await _recentIds([
      _closed(
        'a',
        closedAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 10, 1),
      ),
      _closed(
        'b',
        closedAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      ),
      _closed(
        'c',
        closedAt: DateTime(2026, 5, 10),
        updatedAt: DateTime(2026, 9, 1),
      ),
      _closed(
        'd',
        closedAt: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
      ),
    ]);

    expect(ids, ['d', 'b', 'c']);
  });

  test(
    'an item without a closing date falls back to its last update',
    () async {
      final ids = await _recentIds([
        _closed('no-date', updatedAt: DateTime(2026, 9, 20)),
        _closed(
          'dated',
          closedAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      ]);

      expect(ids, ['no-date', 'dated']);
    },
  );
}
