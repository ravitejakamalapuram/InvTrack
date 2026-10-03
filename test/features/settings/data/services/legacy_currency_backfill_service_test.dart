// A03-F1: records saved before multi-currency support have no `currency`
// field. The repositories label them with the CURRENT base currency at read
// time, so changing the base currency relabelled stored amounts without
// converting them. The backfill writes the base currency into them once.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

Map<String, dynamic> legacyCashFlow({double amount = 100000}) => {
  'investmentId': 'inv-1',
  'date': Timestamp.fromDate(DateTime(2023, 4, 1)),
  'type': 'INVEST',
  'amount': amount,
  'createdAt': Timestamp.fromDate(DateTime(2023, 4, 1)),
};

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore();
  });

  LegacyCurrencyBackfillService build({int chunkSize = 500}) =>
      LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
        chunkSize: chunkSize,
      );

  test('covers every collection whose mapper falls back to the base '
      'currency', () {
    expect(
      LegacyCurrencyBackfillService.collections,
      unorderedEquals([
        'investments',
        'cashflows',
        'archivedInvestments',
        'archivedCashflows',
        'goals',
        'archivedGoals',
        'expectedCashFlows',
      ]),
    );
  });

  test('stamps missing, null and empty currencies with the base currency, '
      'and leaves existing ones alone', () async {
    firestore
      ..put('cashflows', 'missing', legacyCashFlow())
      ..put('cashflows', 'null', {...legacyCashFlow(), 'currency': null})
      ..put('cashflows', 'empty', {...legacyCashFlow(), 'currency': ' '})
      ..put('cashflows', 'usd', {...legacyCashFlow(), 'currency': 'USD'})
      ..put('investments', 'inv-1', {'name': 'FD'})
      ..put('archivedInvestments', 'inv-2', {'name': 'Old FD'})
      ..put('archivedCashflows', 'cf-9', legacyCashFlow())
      ..put('goals', 'g-1', {'name': 'House'})
      ..put('archivedGoals', 'g-2', {'name': 'Car'})
      ..put('expectedCashFlows', 'e-1', {'amount': 500})
      ..put('investments', 'inv-eur', {'name': 'Bond', 'currency': 'EUR'});

    final stamped = await build().backfill('INR');

    expect(stamped, 9);
    expect(firestore.stored('cashflows', 'missing')!['currency'], 'INR');
    expect(firestore.stored('cashflows', 'null')!['currency'], 'INR');
    expect(firestore.stored('cashflows', 'empty')!['currency'], 'INR');
    expect(firestore.stored('cashflows', 'usd')!['currency'], 'USD');
    expect(firestore.stored('investments', 'inv-1')!['currency'], 'INR');
    expect(firestore.stored('investments', 'inv-eur')!['currency'], 'EUR');
    for (final c in ['archivedInvestments', 'archivedCashflows']) {
      expect(firestore.data[c]!.values.single['currency'], 'INR', reason: c);
    }
    for (final c in ['goals', 'archivedGoals', 'expectedCashFlows']) {
      expect(firestore.data[c]!.values.single['currency'], 'INR', reason: c);
    }
    // Only the currency field is added; amounts are never touched.
    expect(firestore.stored('cashflows', 'missing')!['amount'], 100000);
    expect(firestore.stored('cashflows', 'missing')!.keys.toSet(), {
      ...legacyCashFlow().keys,
      'currency',
    });
  });

  test('a second run writes nothing', () async {
    firestore
      ..put('cashflows', 'a', legacyCashFlow())
      ..put('goals', 'g', {'name': 'House'});
    final service = build();

    expect(await service.backfill('INR'), 2);
    final commitsAfterFirstRun = firestore.transactionCount;

    expect(await service.backfill('INR'), 0);
    expect(firestore.transactionCount, commitsAfterFirstRun);
  });

  test('scans the server, never the local cache', () async {
    firestore.put('cashflows', 'a', legacyCashFlow());
    await build().backfill('INR');

    expect(firestore.readOptions, isNotEmpty);
    for (final options in firestore.readOptions) {
      expect(options?.source, Source.server);
    }
  });

  test('does not overwrite a currency written between the scan and the '
      'write (another device)', () async {
    firestore
      ..put('cashflows', 'a', legacyCashFlow())
      ..put('cashflows', 'b', legacyCashFlow());
    firestore.beforeTransaction = () {
      firestore.stored('cashflows', 'a')!['currency'] = 'EUR';
    };

    final stamped = await build().backfill('INR');

    expect(stamped, 1);
    expect(firestore.stored('cashflows', 'a')!['currency'], 'EUR');
    expect(firestore.stored('cashflows', 'b')!['currency'], 'INR');
  });

  test('skips a document deleted between the scan and the write', () async {
    firestore.put('cashflows', 'a', legacyCashFlow());
    firestore.beforeTransaction = () => firestore.data['cashflows']!.clear();

    expect(await build().backfill('INR'), 0);
    expect(firestore.data['cashflows'], isEmpty);
  });

  test('chunks writes to at most 500 per commit', () async {
    for (var i = 0; i < 1201; i++) {
      firestore.put('cashflows', 'cf-$i', legacyCashFlow());
    }

    expect(await build().backfill('INR'), 1201);
    expect(firestore.commitSizes, [500, 500, 201]);
    expect(
      firestore.data['cashflows']!.values.every((d) => d['currency'] == 'INR'),
      isTrue,
    );
  });

  test('rejects a chunk size above the Firestore limit', () {
    expect(() => build(chunkSize: 501), throwsArgumentError);
  });

  test('rejects an empty base currency', () async {
    firestore.put('cashflows', 'a', legacyCashFlow());
    await expectLater(build().backfill(''), throwsArgumentError);
    expect(
      firestore.stored('cashflows', 'a')!.containsKey('currency'),
      isFalse,
    );
  });

  group(
    'original finding: changing base currency relabelled legacy amounts',
    () {
      test('after the backfill, a legacy cash flow keeps INR when the base '
          'currency becomes USD', () async {
        firestore.put('cashflows', 'fd', legacyCashFlow(amount: 1000000));
        await build().backfill('INR');

        final mapped = FirestoreInvestmentRepository.cashFlowFromFirestore(
          firestore.stored('cashflows', 'fd')!,
          'fd',
          baseCurrency: 'USD',
        );

        expect(mapped.currency, 'INR');
        expect(mapped.amount, 1000000);
      });
    },
  );

  group('runOnce', () {
    test('records completion per user and does not rescan', () async {
      firestore.put('cashflows', 'a', legacyCashFlow());
      final service = build();

      expect(service.isComplete, isFalse);
      expect(await service.runOnce('INR'), isTrue);
      expect(service.isComplete, isTrue);
      final reads = firestore.readOptions.length;

      expect(await service.runOnce('INR'), isTrue);
      expect(firestore.readOptions.length, reads);

      final otherUser = LegacyCurrencyBackfillService(
        firestore: FakeLegacyCurrencyFirestore(uid: 'uid-2'),
        userId: 'uid-2',
        prefs: prefs,
      );
      expect(otherUser.isComplete, isFalse);
    });

    test(
      'offline: reports failure, records nothing, retries next time',
      () async {
        firestore.put('cashflows', 'a', legacyCashFlow());
        firestore.readError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
        final service = build();

        expect(await service.runOnce('INR'), isFalse);
        expect(service.isComplete, isFalse);
        expect(
          firestore.stored('cashflows', 'a')!.containsKey('currency'),
          isFalse,
        );

        firestore.readError = null;
        expect(await service.runOnce('INR'), isTrue);
        expect(service.isComplete, isTrue);
        expect(firestore.stored('cashflows', 'a')!['currency'], 'INR');
      },
    );

    test('a failed write is not recorded as complete', () async {
      firestore.put('cashflows', 'a', legacyCashFlow());
      firestore.transactionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      final service = build();

      expect(await service.runOnce('INR'), isFalse);
      expect(service.isComplete, isFalse);
    });

    test('concurrent calls share one run', () async {
      firestore.put('cashflows', 'a', legacyCashFlow());
      final service = build();

      final results = await Future.wait([
        service.runOnce('INR'),
        service.runOnce('INR'),
      ]);

      expect(results, [true, true]);
      expect(
        firestore.readOptions.length,
        LegacyCurrencyBackfillService.collections.length,
      );
    });
  });
}
