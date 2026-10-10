// #936: the custom types listener belongs to the form. Once nothing watches the
// suggestions (the form is closed) the Firestore listener is cancelled, so an
// idle account keeps no live query open (#803). Opening the form again listens
// afresh.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';
import 'package:inv_tracker/features/investment/presentation/providers/custom_investment_type_providers.dart';

/// Counts how many times its stream is listened to and cancelled.
class _CountingRepository implements CustomInvestmentTypeRepository {
  int listens = 0;
  int cancels = 0;

  late final StreamController<List<CustomInvestmentType>> controller =
      StreamController<List<CustomInvestmentType>>.broadcast(
        onListen: () => listens++,
        onCancel: () => cancels++,
      );

  Future<void> close() => controller.close();

  @override
  Stream<List<CustomInvestmentType>> watchAll() => controller.stream;

  @override
  Future<List<CustomInvestmentType>> getAll() async => const [];

  @override
  Future<void> put(CustomInvestmentType type) async {}

  @override
  Future<void> deleteAll() async {}
}

void main() {
  late _CountingRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _CountingRepository();
    container = ProviderContainer(
      overrides: [
        isAuthenticatedProvider.overrideWithValue(true),
        customInvestmentTypeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // Not awaited: close() waits for a paused listener, which the old,
    // never-disposed provider left behind.
    addTearDown(() => unawaited(repository.close()));
  });

  test('the Firestore listener is cancelled once nothing watches the '
      'suggestions', () async {
    final form = container.listen(customTypeSuggestionsProvider, (_, _) {});
    await container.pump();
    expect(repository.controller.hasListener, isTrue, reason: 'form is open');
    expect(repository.listens, 1);

    form.close();
    await container.pump();

    expect(
      repository.controller.hasListener,
      isFalse,
      reason: 'form is closed: no listener may stay on the stream',
    );
    expect(repository.cancels, 1);
    expect(container.exists(customTypeSuggestionsProvider), isFalse);
    expect(container.exists(customInvestmentTypesProvider), isFalse);
  });

  test('reopening the form listens again, and only once', () async {
    container.listen(customTypeSuggestionsProvider, (_, _) {}).close();
    await container.pump();

    final reopened = container.listen(customTypeSuggestionsProvider, (_, _) {});
    await container.pump();
    addTearDown(reopened.close);

    expect(repository.listens, 2);
    expect(repository.cancels, 1);
    expect(repository.controller.hasListener, isTrue);
  });

  test('two widgets watching at once share one listener, and it stays open '
      'until the last one goes', () async {
    final field = container.listen(customTypeSuggestionsProvider, (_, _) {});
    final sheet = container.listen(customTypeSuggestionsProvider, (_, _) {});
    await container.pump();
    expect(repository.listens, 1);

    field.close();
    await container.pump();
    expect(repository.controller.hasListener, isTrue, reason: 'sheet is open');

    sheet.close();
    await container.pump();
    expect(repository.controller.hasListener, isFalse);
    expect(repository.cancels, 1);
  });
}
