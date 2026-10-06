// A81: records saved without a currency are stamped in transactions. Each
// transaction read is a round trip to the server, and a transaction gives up
// after 30 seconds. Reading 500 documents one after another took longer than
// that on a slow network, so the stamp failed and the base-currency change
// was blocked (the v3.73.3 LegacyCurrencyStampException reports).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  FakeLegacyCurrencyFirestore withLegacyCashFlows(int count) {
    final firestore = FakeLegacyCurrencyFirestore();
    for (var i = 0; i < count; i++) {
      firestore.put('cashflows', 'cf-$i', {
        'investmentId': 'fd',
        'type': 'INVEST',
        'amount': 1000.0,
      });
    }
    return firestore;
  }

  LegacyCurrencyBackfillService serviceFor(
    FakeLegacyCurrencyFirestore firestore,
  ) => LegacyCurrencyBackfillService(
    firestore: firestore,
    userId: firestore.uid,
    prefs: prefs,
  );

  test('250 records are stamped in transactions of 100, 100 and 50', () async {
    final firestore = withLegacyCashFlows(250);

    final stamped = await serviceFor(firestore).backfill('INR');

    expect(stamped, 250);
    expect(firestore.commitSizes, [100, 100, 50]);
    expect(firestore.stored('cashflows', 'cf-249')!['currency'], 'INR');
  });

  // testWidgets runs on a fake clock, so the 200 ms reads and the 30 s
  // transaction limit take no real time.
  testWidgets('a transaction reads its documents in parallel', (tester) async {
    final firestore = withLegacyCashFlows(250)
      ..transactionReadLatency = const Duration(milliseconds: 200);

    int? stamped;
    serviceFor(firestore).backfill('INR').then((n) => stamped = n);
    await tester.pump(const Duration(seconds: 5));

    expect(stamped, 250);
    expect(firestore.maxConcurrentTransactionReads, 100);
  });

  testWidgets('500 records in one collection are stamped on a slow network, '
      'inside the 30-second transaction limit', (tester) async {
    final firestore = withLegacyCashFlows(500)
      ..transactionReadLatency = const Duration(milliseconds: 200);

    int? stamped;
    Object? error;
    serviceFor(firestore)
        .backfill('INR')
        .then((n) => stamped = n, onError: (Object e) => error = e);
    await tester.pump(const Duration(minutes: 3));

    expect(error, isNull);
    expect(stamped, 500);
    expect(firestore.updatedDocs, 500);
    expect(serviceFor(firestore).isComplete, isTrue);
  });

  testWidgets('reads slower than the read timeout fail the chunk before the '
      'plugin\'s 30 s transaction wait runs out, and nothing is written', (
    tester,
  ) async {
    final firestore = withLegacyCashFlows(10)
      ..transactionReadLatency = const Duration(seconds: 25);

    Object? error;
    serviceFor(firestore).backfill('INR').catchError((Object e) {
      error = e;
      return 0;
    });
    // Long enough for the reads the failed transaction left running.
    await tester.pump(const Duration(minutes: 2));

    expect(error, isA<TimeoutException>());
    expect(firestore.commitSizes, isEmpty);
    expect(
      firestore.stored('cashflows', 'cf-0')!.containsKey('currency'),
      isFalse,
    );
    expect(serviceFor(firestore).isComplete, isFalse);
  });
}
