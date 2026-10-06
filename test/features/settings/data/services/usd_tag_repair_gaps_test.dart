// A109 and A81 review: records the US dollar question could still miss, and
// how its undo and its chunks behave at the edges.
//  * A user who answered A04 was never asked about an investment that A04
//    skipped (empty then) and that is all in US dollars now.
//  * A partly US dollar investment did not say that its own currency
//    changes.
//  * Sample goals were listed like real ones.
//  * Undo after an archive or restore read twice, each with its own 20 s
//    limit, so it could run past the plugin's 30 s transaction wait.
//  * An investment with more documents than one transaction is written in
//    several; a change made elsewhere between them stops only the rest.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;

  UsdTagRepairService service() => UsdTagRepairService(
    firestore: firestore,
    userId: firestore.uid,
    prefs: prefs,
  );

  String? currencyOf(String collection, String id) =>
      firestore.stored(collection, id)!['currency'] as String?;

  void flow(String id, String investmentId, String currency) {
    firestore.put('cashflows', id, {
      'investmentId': investmentId,
      'type': 'INVEST',
      'amount': 1000.0,
      'currency': currency,
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore();
  });

  group('after the A04 answer', () {
    setUp(() async {
      await prefs.setBool('usd_tag_repair_resolved_${firestore.uid}', true);
    });

    test('an investment that had no cash flows then and is all US dollars '
        'now is listed, unticked', () async {
      firestore.put('investments', 'inv-1', {
        'name': 'New FD',
        'currency': 'USD',
      });
      // Added since the A04 answer; it took the investment's US dollars.
      flow('cf-1', 'inv-1', 'USD');

      final found = await service().findCandidates('INR');

      expect(
        [for (final c in found) (c.id, c.kind, c.tickedByDefault)],
        [('inv-1', UsdTagKind.allUsd, false)],
      );
      expect(service().isResolved, isFalse);
    });

    test('a merged investment all in US dollars is listed again but starts '
        'unticked: the user may have kept it then', () async {
      firestore.put('investments', 'inv-m', {
        'name': 'Merged FD',
        'notes': 'Merged from: FD A, FD B',
        'currency': 'USD',
      });
      flow('cf-m', 'inv-m', 'USD');

      final found = await service().findCandidates('INR');

      expect(
        [for (final c in found) (c.id, c.isMerged, c.tickedByDefault)],
        [('inv-m', true, false)],
      );
    });

    test('Change still relabels it', () async {
      firestore.put('investments', 'inv-1', {
        'name': 'New FD',
        'currency': 'USD',
      });
      flow('cf-1', 'inv-1', 'USD');

      final result = await service().repair({'inv-1'}, 'INR');

      expect(result.documents, 2);
      expect(currencyOf('investments', 'inv-1'), 'INR');
      expect(currencyOf('cashflows', 'cf-1'), 'INR');
    });
  });

  group('a partly US dollar investment', () {
    test('says when its own currency is US dollars', () async {
      firestore
        ..put('investments', 'inv-own', {
          'name': 'Bond ladder',
          'currency': 'USD',
        })
        ..put('investments', 'inv-flows', {'name': 'P2P', 'currency': 'INR'})
        ..put('investments', 'inv-only', {'name': 'Chit', 'currency': 'USD'});
      flow('cf-o1', 'inv-own', 'USD');
      flow('cf-o2', 'inv-own', 'INR');
      flow('cf-f1', 'inv-flows', 'USD');
      flow('cf-f2', 'inv-flows', 'INR');
      // Only the investment itself is in US dollars.
      flow('cf-c1', 'inv-only', 'INR');

      final found = await service().findCandidates('INR');

      expect(
        [
          for (final c in found)
            (c.id, c.kind, c.usdCashFlowCount, c.investmentTagged),
        ],
        [
          ('partly:inv-own', UsdTagKind.partlyUsd, 1, true),
          ('partly:inv-only', UsdTagKind.partlyUsd, 0, true),
          ('partly:inv-flows', UsdTagKind.partlyUsd, 1, false),
        ],
      );
    });
  });

  test('sample goals are never listed', () async {
    firestore
      ..put('goals', 'g-sample', {
        'name': 'Sample goal',
        'targetAmount': 1000000.0,
        'currency': 'USD',
      })
      ..put('goals', 'g-real', {
        'name': 'House',
        'targetAmount': 500000.0,
        'currency': 'USD',
      });
    await prefs.setStringList('sample_data_goal_ids', ['g-sample']);

    final found = await service().findCandidates('INR');

    expect(found.map((c) => c.id), ['goal:g-real']);
  });

  group('undo after the fixed investment was archived', () {
    Future<UsdTagRepairService> fixedThenArchived(WidgetTester tester) async {
      firestore.put('investments', 'inv-1', {'name': 'FD', 'currency': 'USD'});
      flow('cf-1', 'inv-1', 'USD');
      final s = service();
      await tester.runAsync(() => s.repair({'inv-1'}, 'INR'));
      for (final (from, to, id) in [
        ('investments', 'archivedInvestments', 'inv-1'),
        ('cashflows', 'archivedCashflows', 'cf-1'),
      ]) {
        firestore.data.putIfAbsent(to, () => {})[id] = firestore.data[from]!
            .remove(id)!;
      }
      firestore.commitSizes.clear();
      return s;
    }

    // testWidgets runs on a fake clock, so the slow reads take no real time.
    testWidgets('finishes when both reads fit in the read timeout', (
      tester,
    ) async {
      final s = await fixedThenArchived(tester);
      firestore.transactionReadLatency = const Duration(seconds: 9);

      int? restored;
      Object? error;
      s.undo().then(
        (n) => restored = n,
        onError: (Object e) {
          error = e;
          return null;
        },
      );
      await tester.pump(const Duration(minutes: 1));

      expect(error, isNull);
      expect(restored, 2);
      expect(currencyOf('archivedInvestments', 'inv-1'), 'USD');
      expect(currencyOf('archivedCashflows', 'cf-1'), 'USD');
    });

    testWidgets('with reads slower than that fails within one read timeout, '
        'before the plugin\'s 30 s wait, writes nothing and keeps the '
        'backup', (tester) async {
      final s = await fixedThenArchived(tester);
      // Each read is under the 20 s read timeout, but the two rounds
      // together (32 s) are not.
      firestore.transactionReadLatency = const Duration(seconds: 16);

      Object? error;
      s.undo().then(
        (_) {},
        onError: (Object e) {
          error = e;
          return null;
        },
      );
      // Long enough for the reads the failed transaction left running.
      await tester.pump(const Duration(minutes: 2));

      expect(error, isA<TimeoutException>());
      expect(error, isNot(isA<FirebaseException>()));
      expect(firestore.commitSizes, isEmpty);
      expect(currencyOf('archivedCashflows', 'cf-1'), 'INR');
      expect(s.hasBackup, isTrue);
    });
  });

  test('an investment larger than one transaction: a change made elsewhere '
      'before its second transaction stops only the rest, which is listed '
      'again unticked, and undo puts back what was written', () async {
    firestore.put('investments', 'inv-big', {'name': 'P2P', 'currency': 'INR'});
    for (var i = 0; i < 150; i++) {
      flow('cf-$i', 'inv-big', 'USD');
    }
    var transactions = 0;
    firestore.beforeTransaction = () {
      // Another device relabels one cash flow of the second transaction.
      if (++transactions == 2) {
        firestore.stored('cashflows', 'cf-149')!['currency'] = 'INR';
      }
    };

    final result = await service().repair({'inv-big'}, 'INR');

    expect(firestore.commitSizes, [100, 0]);
    expect(result.documents, 100);
    expect(currencyOf('cashflows', 'cf-99'), 'INR');
    expect(currencyOf('cashflows', 'cf-100'), 'USD');
    expect(currencyOf('cashflows', 'cf-149'), 'INR');

    firestore.beforeTransaction = null;
    final again = await service().findCandidates('INR');
    expect(
      [
        for (final c in again)
          (c.id, c.usdCashFlowCount, c.cashFlowCount, c.tickedByDefault),
      ],
      [('partly:inv-big', 49, 150, false)],
    );

    expect(await service().undo(), 100);
    expect(currencyOf('cashflows', 'cf-0'), 'USD');
    expect(currencyOf('cashflows', 'cf-149'), 'INR');
  });
}
