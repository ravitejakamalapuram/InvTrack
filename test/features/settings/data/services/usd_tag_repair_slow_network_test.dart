// A81: the US dollar repair (A04) and its undo write in transactions. Each
// transaction read is a round trip to the server, and a transaction gives up
// after 30 seconds. Reading up to 500 documents one after another took
// longer than that on a slow network, so a large repair or undo failed.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// [count] investments in the base currency, each with one cash flow that
  /// an older import tagged US dollars: one document to change per
  /// investment.
  FakeLegacyCurrencyFirestore withTaggedCashFlows(int count) {
    final firestore = FakeLegacyCurrencyFirestore();
    for (var i = 0; i < count; i++) {
      firestore
        ..put('investments', 'inv-$i', {'name': 'FD $i', 'currency': 'INR'})
        ..put('cashflows', 'cf-$i', {
          'investmentId': 'inv-$i',
          'type': 'INVEST',
          'amount': 1000.0,
          'currency': 'USD',
        });
    }
    return firestore;
  }

  Set<String> ids(int count) => {for (var i = 0; i < count; i++) 'inv-$i'};

  UsdTagRepairService serviceFor(FakeLegacyCurrencyFirestore firestore) =>
      UsdTagRepairService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );

  test('250 documents are repaired in transactions of 100, 100 and 50, '
      'and undone the same way', () async {
    final firestore = withTaggedCashFlows(250);
    final service = serviceFor(firestore);

    final written = await service.repair(ids(250), 'INR');

    expect(written.documents, 250);
    expect(firestore.commitSizes, [100, 100, 50]);
    expect(firestore.stored('cashflows', 'cf-249')!['currency'], 'INR');

    firestore.commitSizes.clear();
    expect(await service.undo(), 250);
    expect(firestore.commitSizes, [100, 100, 50]);
    expect(firestore.stored('cashflows', 'cf-249')!['currency'], 'USD');
  });

  // testWidgets runs on a fake clock, so the 200 ms reads and the 30 s
  // transaction limit take no real time.
  testWidgets('a repair transaction reads its documents in parallel', (
    tester,
  ) async {
    final firestore = withTaggedCashFlows(250)
      ..transactionReadLatency = const Duration(milliseconds: 200);

    int? written;
    serviceFor(
      firestore,
    ).repair(ids(250), 'INR').then((r) => written = r.documents);
    await tester.pump(const Duration(seconds: 5));

    expect(firestore.maxConcurrentTransactionReads, 100);
    expect(written, 250);
  });

  testWidgets('an undo transaction reads its documents in parallel', (
    tester,
  ) async {
    final firestore = withTaggedCashFlows(250);
    final service = serviceFor(firestore);
    await tester.runAsync(() => service.repair(ids(250), 'INR'));
    firestore.transactionReadLatency = const Duration(milliseconds: 200);

    int? restored;
    service.undo().then((n) => restored = n);
    await tester.pump(const Duration(seconds: 5));

    expect(firestore.maxConcurrentTransactionReads, 100);
    expect(restored, 250);
  });

  testWidgets('500 documents are repaired and undone on a slow network, '
      'inside the 30-second transaction limit', (tester) async {
    final firestore = withTaggedCashFlows(500)
      ..transactionReadLatency = const Duration(milliseconds: 200);
    final service = serviceFor(firestore);

    int? documents;
    int? investments;
    Object? error;
    service
        .repair(ids(500), 'INR')
        .then(
          (r) {
            documents = r.documents;
            investments = r.investments;
          },
          onError: (Object e) {
            error = e;
          },
        );
    await tester.pump(const Duration(minutes: 3));

    expect(error, isNull);
    expect(documents, 500);
    expect(investments, 500);
    expect(firestore.updatedDocs, 500);

    int? restored;
    service.undo().then(
      (n) => restored = n,
      onError: (Object e) {
        error = e;
        return null;
      },
    );
    await tester.pump(const Duration(minutes: 3));

    expect(error, isNull);
    expect(restored, 500);
    expect(firestore.stored('cashflows', 'cf-499')!['currency'], 'USD');
    expect(service.hasBackup, isFalse);
  });

  testWidgets('reads slower than the read timeout fail the repair before '
      'the plugin\'s 30 s transaction wait runs out, and nothing is '
      'written', (tester) async {
    final firestore = withTaggedCashFlows(10)
      ..transactionReadLatency = const Duration(seconds: 25);
    final service = serviceFor(firestore);

    Object? error;
    service
        .repair(ids(10), 'INR')
        .then(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );
    // Long enough for the reads the failed transaction left running.
    await tester.pump(const Duration(minutes: 2));

    expect(error, isA<TimeoutException>());
    expect(firestore.commitSizes, isEmpty);
    expect(firestore.stored('cashflows', 'cf-0')!['currency'], 'USD');
    expect(service.hasBackup, isFalse);
    expect(service.isResolved, isFalse);
  });
}
