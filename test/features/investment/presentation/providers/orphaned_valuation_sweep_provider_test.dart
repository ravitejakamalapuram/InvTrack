// #964: the orphaned valuation sweep starts from the app root, only while
// dated valuations are on and a user is signed in, and runs once per session
// however often the flag or the repositories change.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/data/services/orphaned_valuation_cleanup_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockInvestmentRepository extends Mock implements InvestmentRepository {}

class _MockValuationRepository extends Mock implements ValuationRepository {}

class _MockSweepService extends Mock
    implements OrphanedValuationCleanupService {}

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final _flagProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? value) => state = value;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);

void main() {
  late _MockInvestmentRepository investments;
  late _MockValuationRepository valuations;
  late StreamController<Set<String>> idStream;
  late StreamController<List<InvestmentValuationSnapshot>> valuationStream;
  late int idListens;

  ProviderContainer container({
    bool active = true,
    bool signedIn = true,
    bool followFlagProvider = false,
    bool followUidProvider = false,
  }) {
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(any())).thenReturn(userDoc);
    when(() => userDoc.collection('valuations')).thenReturn(_MockCollection());
    final c = ProviderContainer(
      overrides: [
        valuationSnapshotsActiveProvider.overrideWith(
          (ref) => followFlagProvider ? ref.watch(_flagProvider) : active,
        ),
        isAuthenticatedProvider.overrideWith(
          (ref) =>
              followUidProvider ? ref.watch(_uidProvider) != null : signedIn,
        ),
        valuationAccountIdProvider.overrideWith(
          (ref) => followUidProvider
              ? ref.watch(_uidProvider)
              : (signedIn ? 'u1' : null),
        ),
        firestoreProvider.overrideWithValue(firestore),
        investmentRepositoryProvider.overrideWithValue(investments),
        valuationRepositoryProvider.overrideWithValue(valuations),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    investments = _MockInvestmentRepository();
    valuations = _MockValuationRepository();
    idStream = StreamController<Set<String>>.broadcast();
    valuationStream =
        StreamController<List<InvestmentValuationSnapshot>>.broadcast();
    idListens = 0;
    when(() => investments.watchServerConfirmedInvestmentIds()).thenAnswer((_) {
      idListens++;
      return idStream.stream;
    });
    when(
      () => valuations.watchServerConfirmed(),
    ).thenAnswer((_) => valuationStream.stream);
  });

  tearDown(() {
    unawaited(idStream.close());
    unawaited(valuationStream.close());
  });

  test('does not look at the server while dated valuations are off', () async {
    final c = container(active: false);

    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();

    expect(idListens, 0);
  });

  test('does nothing when nobody is signed in', () async {
    final c = container(signedIn: false);

    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();

    expect(idListens, 0);
  });

  test('waits for the server-confirmed investments and valuations when '
      'dated valuations are on', () async {
    final c = container();

    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();

    expect(idListens, 1);
    verify(() => valuations.watchServerConfirmed()).called(1);
  });

  test('turning the flag off and on again in one session does not sweep a '
      'second time', () async {
    final c = container(followFlagProvider: true);
    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();

    idStream.add({'live'});
    valuationStream.add(const []);
    await pumpEventQueue();
    expect(idListens, 1);

    c.read(_flagProvider.notifier).set(false);
    await pumpEventQueue();
    c.read(_flagProvider.notifier).set(true);
    await pumpEventQueue();

    expect(idListens, 1);
  });

  test('signing out closes the listeners of a sweep that is still waiting '
      'for the server', () async {
    final c = container(followUidProvider: true);
    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();
    expect(idStream.hasListener, isTrue);

    c.read(_uidProvider.notifier).set(null);
    await pumpEventQueue();

    expect(idStream.hasListener, isFalse);
    expect(valuationStream.hasListener, isFalse);
  });

  test('switching account cancels the old sweep and starts one for the '
      'new user', () async {
    final c = container(followUidProvider: true);
    c.listen(orphanedValuationSweepProvider, (_, _) {});
    await pumpEventQueue();
    expect(idListens, 1);

    c.read(_uidProvider.notifier).set('u2');
    await pumpEventQueue();

    expect(idListens, 2);
  });

  // A sweep that failed (the server was out of reach) is tried again later in
  // the same session instead of waiting for the next app start.
  group('after a failed sweep', () {
    ProviderContainer retryContainer(_MockSweepService service) {
      final c = ProviderContainer(
        overrides: [
          valuationSnapshotsActiveProvider.overrideWithValue(true),
          isAuthenticatedProvider.overrideWithValue(true),
          orphanedValuationCleanupServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('tries again after a delay and stops once it finishes', (
      tester,
    ) async {
      final service = _MockSweepService();
      final results = [false, true];
      when(service.runOnce).thenAnswer((_) async => results.removeAt(0));
      final c = retryContainer(service);

      c.listen(orphanedValuationSweepProvider, (_, _) {});
      await tester.pump();
      verify(service.runOnce).called(1);

      await tester.pump(const Duration(seconds: 29));
      verifyNever(service.runOnce);

      await tester.pump(const Duration(seconds: 2));
      verify(service.runOnce).called(1);

      await tester.pump(const Duration(hours: 1));
      verifyNever(service.runOnce);
    });

    testWidgets('gives up after three retries', (tester) async {
      final service = _MockSweepService();
      when(service.runOnce).thenAnswer((_) async => false);
      final c = retryContainer(service);

      c.listen(orphanedValuationSweepProvider, (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(hours: 1));

      verify(service.runOnce).called(4);
    });

    testWidgets('signing out or switching account cancels a pending retry', (
      tester,
    ) async {
      final service = _MockSweepService();
      when(service.runOnce).thenAnswer((_) async => false);
      final c = retryContainer(service);
      c.listen(orphanedValuationSweepProvider, (_, _) {});
      await tester.pump();
      verify(service.runOnce).called(1);

      c.dispose();
      await tester.pump(const Duration(hours: 1));

      verifyNever(service.runOnce);
    });
  });
}
