// #936: saving, renaming and removing reusable custom types. Every change
// touches one definition; investments and cash flows are never read or
// written, so a rename or removal cannot reclassify or delete them.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:inv_tracker/features/investment/presentation/providers/custom_investment_type_providers.dart';

import '../../data/repositories/fake_custom_investment_type_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

ProviderContainer _container(
  FakeCustomInvestmentTypeRepository types, {
  FakeInvestmentRepository? investments,
}) {
  final container = ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(true),
      customInvestmentTypeRepositoryProvider.overrideWithValue(types),
      investmentRepositoryProvider.overrideWithValue(
        investments ?? FakeInvestmentRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<List<CustomInvestmentType>> _suggestions(ProviderContainer c) async {
  // A provider with no listener is paused (as with a screen that is closed).
  c.listen(customTypeSuggestionsProvider, (_, _) {});
  await c.read(customInvestmentTypesProvider.future);
  return c.read(customTypeSuggestionsProvider);
}

void main() {
  late FakeCustomInvestmentTypeRepository types;
  late ProviderContainer container;

  CustomInvestmentTypeNotifier notifier() =>
      container.read(customInvestmentTypeNotifierProvider.notifier);

  setUp(() {
    types = FakeCustomInvestmentTypeRepository();
    container = _container(types);
  });

  test('a saved label becomes a suggestion', () async {
    final change = await notifier().save('  Art   Prints ');

    expect(change.issue, isNull);
    expect(change.result!.label, 'Art Prints');
    expect((await _suggestions(container)).map((d) => d.label), ['Art Prints']);
  });

  test('saved labels are still suggested after a restart', () async {
    await notifier().save('Art Prints');
    await notifier().save('Vintage Cars');

    // A new container over the same storage: nothing is held in memory.
    final restarted = _container(types);

    expect((await _suggestions(restarted)).map((d) => d.label), [
      'Art Prints',
      'Vintage Cars',
    ]);
  });

  test('case and spacing variants never make a second type', () async {
    final first = await notifier().save('Art Prints');
    final writesAfterFirst = types.writes;

    final variants = [
      await notifier().save('art prints'),
      await notifier().save('  ART   PRINTS  '),
      await notifier().save('Art\u00A0Prints'),
    ];

    expect(variants.map((c) => c.result!.id), everyElement(first.result!.id));
    expect(
      types.writes,
      writesAfterFirst,
      reason: 'an existing key is no write',
    );
    expect(await _suggestions(container), hasLength(1));
  });

  test('a blank label is refused and nothing is written', () async {
    final change = await notifier().save('  \t ');
    expect(change.issue, CustomTypeIssue.blank);
    expect(types.writes, 0);
  });

  test(
    'the 51st active type is refused, and an existing one still resolves',
    () async {
      for (var i = 0; i < 50; i++) {
        expect((await notifier().save('Type $i')).issue, isNull);
      }

      final extra = await notifier().save('One more');
      expect(extra.issue, CustomTypeIssue.atCapacity);
      expect(types.definitions, hasLength(50));

      final existing = await notifier().save('type 7');
      expect(existing.issue, isNull);
      expect(existing.result!.label, 'Type 7');
    },
  );

  test(
    'removing hides the suggestion and saving the label again revives it',
    () async {
      final saved = (await notifier().save('Art Prints')).result!;

      await notifier().remove(saved.id);
      expect(await _suggestions(container), isEmpty);
      expect(types.definitions.single.isRemoved, isTrue);

      final revived = await notifier().save('art prints');
      expect(revived.result!.id, saved.id);
      expect(revived.result!.label, 'Art Prints');
      expect((await _suggestions(container)).map((d) => d.id), [saved.id]);
      expect(types.definitions, hasLength(1));
    },
  );

  test('renaming changes that one suggestion only', () async {
    final art = (await notifier().save('Art')).result!;
    await notifier().save('Wine');

    final change = await notifier().rename(art.id, 'Paintings');

    expect(change.issue, isNull);
    expect((await _suggestions(container)).map((d) => d.label), [
      'Paintings',
      'Wine',
    ]);
  });

  test('renaming onto another type, active or removed, is refused', () async {
    final art = (await notifier().save('Art')).result!;
    final wine = (await notifier().save('Wine')).result!;
    await notifier().remove(wine.id);

    final change = await notifier().rename(art.id, ' wine ');

    expect(change.issue, CustomTypeIssue.duplicate);
    expect(types.definitions.firstWhere((d) => d.id == art.id).label, 'Art');
  });

  group('existing investments', () {
    late FakeInvestmentRepository investments;
    late InvestmentEntity stamps;
    late CashFlowEntity flow;

    setUp(() {
      investments = FakeInvestmentRepository();
      stamps = InvestmentEntity(
        id: 'inv-stamps',
        name: 'Stamp album',
        type: InvestmentType.other,
        status: InvestmentStatus.open,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        currency: 'INR',
        customTypeId: 'c1',
        customTypeLabel: 'Stamps',
      );
      flow = CashFlowEntity(
        id: 'cf-1',
        investmentId: 'inv-stamps',
        type: CashFlowType.invest,
        amount: 25000.50,
        date: DateTime(2026, 1, 5),
        createdAt: DateTime(2026, 1, 5),
        currency: 'INR',
      );
      investments.seed(investments: [stamps], cashFlows: [flow]);
      types = FakeCustomInvestmentTypeRepository([
        CustomInvestmentType(
          id: 'c1',
          label: 'Stamps',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      container = _container(types, investments: investments);
    });

    test(
      'removing the type leaves the investment and its cash flows as they were',
      () async {
        await notifier().remove('c1');

        expect(investments.investments.single, stamps);
        expect(investments.investments.single.typeLabel, 'Stamps');
        expect(investments.cashFlows.single, flow);
        expect(types.definitions.single.isRemoved, isTrue);
      },
    );

    test('renaming the type does not change the investment either', () async {
      await notifier().rename('c1', 'Philately');

      expect(investments.investments.single, stamps);
      expect(investments.investments.single.typeLabel, 'Stamps');
      expect(investments.cashFlows.single, flow);
      expect(types.definitions.single.label, 'Philately');
    });
  });
}
