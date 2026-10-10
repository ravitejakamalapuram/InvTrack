// #936: the list search also finds an Other investment by its custom label,
// while the flag is on. The type filter keeps using the built-in type, so
// filtering and grouping stay stable.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

import '../../data/repositories/mock_investment_repository.dart';

InvestmentEntity _inv(
  String id,
  String name,
  InvestmentType type, [
  String? label,
]) => InvestmentEntity(
  id: id,
  name: name,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
  customTypeLabel: label,
);

void main() {
  late ProviderContainer container;

  Future<List<String>> names({
    required bool flag,
    String query = '',
    InvestmentType? typeFilter,
  }) async {
    final repo = FakeInvestmentRepository()
      ..seed(
        investments: [
          _inv('a', 'Album', InvestmentType.other, 'Stamps'),
          _inv('b', 'Cellar', InvestmentType.other),
          _inv('c', 'Bond', InvestmentType.bonds),
        ],
      );
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        isAuthenticatedProvider.overrideWithValue(true),
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
      ],
    );
    addTearDown(container.dispose);
    container.listen(filteredInvestmentsProvider, (_, _) {});
    await container.read(allInvestmentsProvider.future);
    final list = container.read(investmentListStateProvider.notifier)
      ..setSearchQuery(query);
    if (typeFilter != null) list.setTypeFilter(typeFilter);
    return [
      for (final i in container.read(filteredInvestmentsProvider).value ?? [])
        i.name,
    ];
  }

  test('search finds an investment by its custom label', () async {
    expect(await names(flag: true, query: 'stamp'), ['Album']);
  });

  test('search by "other" still finds every Other investment', () async {
    expect((await names(flag: true, query: 'other')).toSet(), {
      'Album',
      'Cellar',
    });
  });

  test('flag off: the label is not searched', () async {
    expect(await names(flag: false, query: 'stamp'), isEmpty);
  });

  test('the type filter still groups by the built-in type', () async {
    expect(
      (await names(flag: true, typeFilter: InvestmentType.other)).toSet(),
      {'Album', 'Cellar'},
    );
  });
}
