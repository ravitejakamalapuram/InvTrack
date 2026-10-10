// #936: the investment form sends the text typed in "Custom type". The
// notifier decides what the investment stores: nothing for blank text or for
// a built-in type, a link to a reusable type when the text matches an active
// one, otherwise a label for that investment only. The built-in type stays
// Other and nothing else about the investment changes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../data/repositories/fake_custom_investment_type_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

CustomInvestmentType _def(String id, String label, {DateTime? removedAt}) =>
    CustomInvestmentType(
      id: id,
      label: label,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      removedAt: removedAt,
    );

void main() {
  late FakeInvestmentRepository investments;
  late FakeCustomInvestmentTypeRepository types;
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  void build([List<CustomInvestmentType> defs = const []]) {
    investments = FakeInvestmentRepository();
    types = FakeCustomInvestmentTypeRepository(defs);
    analytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(investments),
        customInvestmentTypeRepositoryProvider.overrideWithValue(types),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    addTearDown(container.dispose);
  }

  setUp(build);

  Future<InvestmentEntity> add({
    InvestmentType type = InvestmentType.other,
    String? label,
  }) => notifier().addInvestment(
    name: 'Stamp album',
    type: type,
    customTypeLabel: label,
  );

  group('addInvestment', () {
    test(
      'blank or missing text keeps today\'s behaviour: plain Other',
      () async {
        for (final text in [null, '', '   ']) {
          final inv = await add(label: text);
          expect(inv.type, InvestmentType.other);
          expect(inv.customTypeId, isNull);
          expect(inv.customTypeLabel, isNull);
          expect(inv.typeLabel, 'Other');
        }
      },
    );

    test(
      'text that matches no saved type is a label for this investment only',
      () async {
        final inv = await add(label: '  Rare   Stamps ');
        expect(inv.type, InvestmentType.other);
        expect(inv.customTypeId, isNull);
        expect(inv.customTypeLabel, 'Rare Stamps');
        expect(
          types.writes,
          0,
          reason: 'a label is never saved as a type silently',
        );
        expect(investments.investments.single, inv);
      },
    );

    test(
      'text that matches an active saved type links to it and takes its casing',
      () async {
        build([_def('c1', 'Rare Stamps')]);

        final inv = await add(label: 'rare   STAMPS');

        expect(inv.customTypeId, 'c1');
        expect(inv.customTypeLabel, 'Rare Stamps');
        expect(types.writes, 0);
      },
    );

    test(
      'text that matches only a removed type is a label for this investment only',
      () async {
        build([_def('c1', 'Rare Stamps', removedAt: DateTime.utc(2026, 2, 1))]);

        final inv = await add(label: 'rare stamps');

        expect(inv.customTypeId, isNull);
        expect(inv.customTypeLabel, 'rare stamps');
      },
    );

    test('a built-in type never keeps a custom label', () async {
      final inv = await add(type: InvestmentType.bonds, label: 'Rare Stamps');
      expect(inv.type, InvestmentType.bonds);
      expect(inv.customTypeId, isNull);
      expect(inv.customTypeLabel, isNull);
      expect(inv.typeLabel, 'Bonds/Debentures');
    });

    test(
      'a label over 40 characters is refused and nothing is saved',
      () async {
        await expectLater(
          add(label: 'x' * 41),
          throwsA(isA<ValidationException>()),
        );
        expect(investments.investments, isEmpty);
      },
    );

    test('exactly 40 characters is accepted', () async {
      final inv = await add(label: 'x' * 40);
      expect(inv.customTypeLabel, 'x' * 40);
    });

    test('the label never reaches analytics', () async {
      build([_def('c1', 'Rare Stamps')]);

      await add(label: 'Rare Stamps');
      await add(label: 'Secret Hobby Fund');

      expect(analytics.loggedEvents, isNotEmpty);
      for (final event in analytics.loggedEvents) {
        final text = '${event.name} ${event.parameters}'.toLowerCase();
        expect(text, isNot(contains('stamps')));
        expect(text, isNot(contains('secret')));
        expect(text, isNot(contains('hobby')));
        expect(
          event.parameters?['investment_type'] ?? 'other',
          'other',
          reason: 'only the built-in type name is reported',
        );
      }
    });
  });

  group('updateInvestment', () {
    InvestmentEntity seed({String? id, String? label, InvestmentType? type}) {
      final inv = InvestmentEntity(
        id: 'inv-1',
        name: 'Stamp album',
        type: type ?? InvestmentType.other,
        status: InvestmentStatus.open,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        currency: 'INR',
        customTypeId: id,
        customTypeLabel: label,
      );
      investments.seed(investments: [inv]);
      return inv;
    }

    Future<void> edit(
      InvestmentEntity from, {
      String? label,
      InvestmentType? type,
      String name = 'Stamp album',
    }) => notifier().updateInvestment(
      id: from.id,
      name: name,
      type: type ?? from.type,
      currency: from.currency,
      customTypeLabel: label,
    );

    test(
      'saving unchanged keeps the link even after the type was renamed',
      () async {
        build([_def('c1', 'Philately')]);
        final inv = seed(id: 'c1', label: 'Stamps');

        await edit(inv, label: 'Stamps', name: 'Stamp album 2');

        final stored = investments.investments.single;
        expect(stored.customTypeId, 'c1');
        expect(stored.customTypeLabel, 'Stamps');
      },
    );

    test('an investment with no custom type can get one', () async {
      build([_def('c1', 'Stamps')]);
      final inv = seed();

      await edit(inv, label: 'stamps');

      final stored = investments.investments.single;
      expect(stored.customTypeId, 'c1');
      expect(stored.customTypeLabel, 'Stamps');
      expect(stored.type, InvestmentType.other);
    });

    test('clearing the field removes the custom type', () async {
      build([_def('c1', 'Stamps')]);
      final inv = seed(id: 'c1', label: 'Stamps');

      await edit(inv, label: '');

      final stored = investments.investments.single;
      expect(stored.customTypeId, isNull);
      expect(stored.customTypeLabel, isNull);
      expect(stored.typeLabel, 'Other');
      expect(types.definitions.single.isRemoved, isFalse);
    });

    test('changing the type away from Other drops the custom type', () async {
      build([_def('c1', 'Stamps')]);
      final inv = seed(id: 'c1', label: 'Stamps');

      await edit(inv, type: InvestmentType.bonds, label: 'Stamps');

      final stored = investments.investments.single;
      expect(stored.type, InvestmentType.bonds);
      expect(stored.customTypeId, isNull);
      expect(stored.customTypeLabel, isNull);
    });

    test('setting the current value keeps the custom type', () async {
      final inv = seed(id: 'c1', label: 'Stamps');

      await notifier().setCurrentValue(
        id: inv.id,
        value: 5000,
        date: DateTime(2026, 9, 1),
      );
      await notifier().clearCurrentValue(inv.id);

      final stored = investments.investments.single;
      expect(stored.customTypeId, 'c1');
      expect(stored.customTypeLabel, 'Stamps');
    });
  });

  test('merging Other investments keeps their custom label', () async {
    build();
    investments.seed(
      investments: [
        for (final (id, label) in [('a', 'Stamps'), ('b', null)])
          InvestmentEntity(
            id: id,
            name: 'Album $id',
            type: InvestmentType.other,
            status: InvestmentStatus.open,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            currency: 'INR',
            customTypeId: label == null ? null : 'c1',
            customTypeLabel: label,
          ),
      ],
    );

    // The app always has a screen listening to the investments stream.
    container.listen(allInvestmentsProvider, (_, _) {});
    await notifier().mergeInvestments(['a', 'b'], 'Merged albums');

    final merged = investments.investments.single;
    expect(merged.type, InvestmentType.other);
    expect(merged.customTypeId, 'c1');
    expect(merged.customTypeLabel, 'Stamps');
  });
}
