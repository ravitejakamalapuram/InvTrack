// A04: investments that older versions saved as US dollars by mistake
// (merge, CSV import, restore) are found, and only the ones the user
// confirms are relabelled with the base currency. The amounts never change,
// a backup is saved before any write, and the repair can be undone.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;

  UsdTagRepairService service({int chunkSize = 500}) => UsdTagRepairService(
    firestore: firestore,
    userId: firestore.uid,
    prefs: prefs,
    chunkSize: chunkSize,
  );

  String? currencyOf(String collection, String id) =>
      firestore.stored(collection, id)!['currency'] as String?;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore()
      // Merged before A03: every copied flow was re-tagged USD.
      ..put('investments', 'inv-merged', {
        'name': 'Merged FD',
        'notes': 'Merged from: FD A, FD B',
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-m1', {
        'investmentId': 'inv-merged',
        'type': 'INVEST',
        'amount': 500000.0,
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-m2', {
        'investmentId': 'inv-merged',
        'type': 'INVEST',
        'amount': 300000.0,
        'currency': 'USD',
      })
      // Imported from a CSV without a currency column before A03.
      ..put('investments', 'inv-imported', {
        'name': 'Imported bond',
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-i1', {
        'investmentId': 'inv-imported',
        'type': 'INVEST',
        'amount': 100000.0,
        'currency': 'USD',
      })
      // Correctly tagged in the base currency.
      ..put('investments', 'inv-inr', {'name': 'SBI FD', 'currency': 'INR'})
      ..put('cashflows', 'cf-r1', {
        'investmentId': 'inv-inr',
        'type': 'INVEST',
        'amount': 200000.0,
        'currency': 'INR',
      })
      // Mixed currencies: ambiguous, never flagged.
      ..put('investments', 'inv-mixed', {'name': 'Mixed', 'currency': 'USD'})
      ..put('cashflows', 'cf-x1', {
        'investmentId': 'inv-mixed',
        'type': 'INVEST',
        'amount': 1000.0,
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-x2', {
        'investmentId': 'inv-mixed',
        'type': 'RETURN',
        'amount': 1100.0,
        'currency': 'INR',
      })
      // No cash flows: nothing to inflate, never flagged.
      ..put('investments', 'inv-empty', {'name': 'Empty', 'currency': 'USD'})
      // Archived investment imported before A03.
      ..put('archivedInvestments', 'arch-1', {
        'name': 'Old P2P',
        'currency': 'USD',
      })
      ..put('archivedCashflows', 'acf-1', {
        'investmentId': 'arch-1',
        'type': 'INVEST',
        'amount': 50000.0,
        'currency': 'USD',
      });
  });

  group('findCandidates', () {
    test('with base INR flags merged and imported all-USD investments, '
        'active and archived, and nothing else', () async {
      final found = await service().findCandidates('INR');

      expect(
        [
          for (final c in found)
            (c.investmentId, c.isMerged, c.isArchived, c.cashFlowCount),
        ],
        [
          ('inv-imported', false, false, 1),
          ('inv-merged', true, false, 2),
          ('arch-1', false, true, 1),
        ],
      );
      expect(found.map((c) => c.name), [
        'Imported bond',
        'Merged FD',
        'Old P2P',
      ]);
    });

    test('reads from the server only and writes nothing', () async {
      await service().findCandidates('INR');

      expect(firestore.readOptions, isNotEmpty);
      expect(
        firestore.readOptions.every((o) => o?.source == Source.server),
        isTrue,
      );
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isFalse);
      expect(service().hasBackup, isFalse);
    });

    test('never flags the sample investments, which are in US dollars on '
        'purpose', () async {
      await prefs.setStringList('sample_data_investment_ids', ['inv-imported']);

      final found = await service().findCandidates('INR');

      expect(found.map((c) => c.investmentId), ['inv-merged', 'arch-1']);
      expect(await service().repair({'inv-imported'}, 'INR'), (
        documents: 0,
        investments: 0,
      ));
      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
    });

    test('with base USD flags nothing and reads nothing', () async {
      final found = await service().findCandidates('USD');

      expect(found, isEmpty);
      expect(firestore.readOptions, isEmpty);
    });

    test('throws when the server cannot be reached', () async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        service().findCandidates('INR'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('repair', () {
    test('rewrites the currency only for confirmed investments and keeps '
        'the amounts', () async {
      final written = await service().repair({'inv-merged'}, 'INR');

      expect(written, (documents: 3, investments: 1));
      expect(currencyOf('investments', 'inv-merged'), 'INR');
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
      expect(currencyOf('cashflows', 'cf-m2'), 'INR');
      expect(firestore.stored('cashflows', 'cf-m1')!['amount'], 500000.0);
      expect(firestore.stored('cashflows', 'cf-m2')!['amount'], 300000.0);
      // Not confirmed: untouched.
      expect(currencyOf('investments', 'inv-imported'), 'USD');
      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
      expect(currencyOf('archivedInvestments', 'arch-1'), 'USD');
      expect(currencyOf('archivedCashflows', 'acf-1'), 'USD');
      expect(currencyOf('cashflows', 'cf-x1'), 'USD');
      expect(service().isResolved, isTrue);
    });

    test('repairs confirmed archived investments too', () async {
      final written = await service().repair({'arch-1'}, 'INR');

      expect(written, (documents: 2, investments: 1));
      expect(currencyOf('archivedInvestments', 'arch-1'), 'INR');
      expect(currencyOf('archivedCashflows', 'acf-1'), 'INR');
    });

    test('is idempotent: a second run writes nothing', () async {
      await service().repair({'inv-merged', 'inv-imported'}, 'INR');
      final commitsAfterFirst = firestore.updatedDocs;
      final backupAfterFirst = prefs.getString(
        'usd_tag_repair_backup_${firestore.uid}',
      );

      final second = await service().repair({
        'inv-merged',
        'inv-imported',
      }, 'INR');

      expect(second, (documents: 0, investments: 0));
      expect(firestore.updatedDocs, commitsAfterFirst);
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
      expect(currencyOf('cashflows', 'cf-i1'), 'INR');
      expect(
        prefs.getString('usd_tag_repair_backup_${firestore.uid}'),
        backupAfterFirst,
      );
    });

    test('never touches investments that are not all USD, even when '
        'confirmed', () async {
      final written = await service().repair({
        'inv-inr',
        'inv-mixed',
        'inv-empty',
      }, 'INR');

      expect(written, (documents: 0, investments: 0));
      expect(currencyOf('investments', 'inv-inr'), 'INR');
      expect(currencyOf('cashflows', 'cf-x1'), 'USD');
      expect(currencyOf('cashflows', 'cf-x2'), 'INR');
      expect(currencyOf('investments', 'inv-empty'), 'USD');
    });

    test('skips the whole investment when one of its documents changed '
        'after the scan, so it never ends up with mixed currencies', () async {
      firestore.beforeTransaction = () {
        firestore.stored('cashflows', 'cf-m2')!['currency'] = 'EUR';
      };

      final written = await service().repair({'inv-merged'}, 'INR');

      expect(written, (documents: 0, investments: 0));
      expect(currencyOf('investments', 'inv-merged'), 'USD');
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(currencyOf('cashflows', 'cf-m2'), 'EUR');
      // Nothing was written, so there is nothing to undo.
      expect(service().hasBackup, isFalse);
    });

    test('a changed investment is skipped while the others in the same '
        'transaction are still repaired', () async {
      firestore.beforeTransaction = () {
        firestore.stored('cashflows', 'cf-m2')!['currency'] = 'EUR';
      };

      final written = await service().repair({
        'inv-merged',
        'inv-imported',
      }, 'INR');

      expect(written, (documents: 2, investments: 1));
      expect(currencyOf('investments', 'inv-merged'), 'USD');
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(currencyOf('investments', 'inv-imported'), 'INR');
      expect(currencyOf('cashflows', 'cf-i1'), 'INR');
      // The backup lists only what was written, so undo cannot touch the
      // skipped investment.
      final backup =
          jsonDecode(prefs.getString('usd_tag_repair_backup_${firestore.uid}')!)
              as List;
      expect([
        for (final e in backup) '${e['c']}/${e['id']}',
      ], unorderedEquals(['investments/inv-imported', 'cashflows/cf-i1']));
    });

    test('saves the backup before the first write', () async {
      List<dynamic>? backupAtWrite;
      firestore.beforeTransaction = () {
        backupAtWrite =
            jsonDecode(
                  prefs.getString('usd_tag_repair_backup_${firestore.uid}')!,
                )
                as List;
      };

      await service().repair({'inv-merged'}, 'INR');

      expect(
        [
          for (final e in backupAtWrite!)
            (e['c'], e['id'], e['inv'], e['from'], e['to']),
        ],
        unorderedEquals([
          ('investments', 'inv-merged', 'inv-merged', 'USD', 'INR'),
          ('cashflows', 'cf-m1', 'inv-merged', 'USD', 'INR'),
          ('cashflows', 'cf-m2', 'inv-merged', 'USD', 'INR'),
        ]),
      );
    });

    test('after a run interrupted before its write, the backup lists each '
        'document once', () async {
      // Process death after the backup was saved, before the transaction.
      await prefs.setString(
        'usd_tag_repair_backup_${firestore.uid}',
        jsonEncode([
          {
            'c': 'cashflows',
            'id': 'cf-m1',
            'inv': 'inv-merged',
            'from': 'USD',
            'to': 'INR',
          },
        ]),
      );

      await service().repair({'inv-merged'}, 'INR');

      final backup =
          jsonDecode(prefs.getString('usd_tag_repair_backup_${firestore.uid}')!)
              as List;
      expect(
        [for (final e in backup) '${e['c']}/${e['id']}'],
        unorderedEquals([
          'investments/inv-merged',
          'cashflows/cf-m1',
          'cashflows/cf-m2',
        ]),
      );
      expect(service().backedUpInvestmentCount, 1);
    });

    test('keeps every document of one investment in one transaction', () async {
      final written = await service(
        chunkSize: 2,
      ).repair({'inv-merged', 'inv-imported'}, 'INR');

      expect(written, (documents: 5, investments: 2));
      // inv-imported (2 docs) fits one chunk; inv-merged (3 docs) is larger
      // than the chunk size and is split only because it must be.
      expect(firestore.commitSizes, [2, 2, 1]);
    });

    test('offline: writes nothing and is not marked resolved', () async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        service().repair({'inv-merged'}, 'INR'),
        throwsA(isA<FirebaseException>()),
      );
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isFalse);
      expect(service().hasBackup, isFalse);
    });

    test('a failed write is not marked resolved and leaves no backup '
        'entries for unwritten documents', () async {
      firestore.transactionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        service().repair({'inv-merged'}, 'INR'),
        throwsA(isA<FirebaseException>()),
      );
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(service().isResolved, isFalse);
      expect(service().hasBackup, isFalse);
    });

    test('refuses USD or an empty currency as the target', () async {
      expect(
        () => service().repair({'inv-merged'}, 'USD'),
        throwsArgumentError,
      );
      expect(() => service().repair({'inv-merged'}, ' '), throwsArgumentError);
      expect(firestore.readOptions, isEmpty);
    });
  });

  group('undo', () {
    test('restores US dollars on every repaired document and is '
        'idempotent', () async {
      await service().repair({'inv-merged', 'arch-1'}, 'INR');
      expect(service().backedUpInvestmentCount, 2);

      final restored = await service().undo();

      expect(restored, 5);
      expect(currencyOf('investments', 'inv-merged'), 'USD');
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(currencyOf('cashflows', 'cf-m2'), 'USD');
      expect(currencyOf('archivedInvestments', 'arch-1'), 'USD');
      expect(currencyOf('archivedCashflows', 'acf-1'), 'USD');
      expect(firestore.stored('cashflows', 'cf-m1')!['amount'], 500000.0);
      expect(service().hasBackup, isFalse);
      // The answer stands: the start-up question is not asked again.
      expect(service().isResolved, isTrue);

      expect(await service().undo(), 0);
    });

    test('never overwrites a currency changed after the repair', () async {
      await service().repair({'inv-merged'}, 'INR');
      firestore.stored('cashflows', 'cf-m1')!['currency'] = 'EUR';

      final restored = await service().undo();

      expect(restored, 2);
      expect(currencyOf('cashflows', 'cf-m1'), 'EUR');
      expect(currencyOf('cashflows', 'cf-m2'), 'USD');
    });

    // An investment archived (or restored) between the repair and Undo
    // keeps its document ids but moves to the other collections.
    void move(String id, String from, String to) =>
        firestore.data.putIfAbsent(to, () => {})[id] = firestore.data[from]!
            .remove(id)!;

    test('restores an investment archived after the repair', () async {
      await service().repair({'inv-merged'}, 'INR');
      move('inv-merged', 'investments', 'archivedInvestments');
      move('cf-m1', 'cashflows', 'archivedCashflows');
      move('cf-m2', 'cashflows', 'archivedCashflows');

      final restored = await service().undo();

      expect(restored, 3);
      expect(currencyOf('archivedInvestments', 'inv-merged'), 'USD');
      expect(currencyOf('archivedCashflows', 'cf-m1'), 'USD');
      expect(currencyOf('archivedCashflows', 'cf-m2'), 'USD');
      expect(firestore.stored('investments', 'inv-merged'), isNull);
      expect(firestore.stored('cashflows', 'cf-m1'), isNull);
      expect(service().hasBackup, isFalse);
    });

    test('restores an archived investment restored after the repair', () async {
      await service().repair({'arch-1'}, 'INR');
      move('arch-1', 'archivedInvestments', 'investments');
      move('acf-1', 'archivedCashflows', 'cashflows');

      final restored = await service().undo();

      expect(restored, 2);
      expect(currencyOf('investments', 'arch-1'), 'USD');
      expect(currencyOf('cashflows', 'acf-1'), 'USD');
      expect(firestore.stored('archivedInvestments', 'arch-1'), isNull);
      expect(service().hasBackup, isFalse);
    });

    test('keeps the backup when the undo fails', () async {
      await service().repair({'inv-merged'}, 'INR');
      firestore.transactionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(service().undo(), throwsA(isA<FirebaseException>()));
      expect(service().hasBackup, isTrue);
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
    });
  });

  test('Keep records the answer without writing anything', () async {
    await service().markResolved();

    expect(service().isResolved, isTrue);
    expect(firestore.transactionCount, 0);
  });

  group('the answer is kept for the account, not only this device', () {
    test('markResolved saves it on users/{uid}', () async {
      await service().markResolved();

      expect(firestore.userFields, contains(UsdTagRepairService.resolvedField));
    });

    test('a repair saves it on users/{uid}', () async {
      await service().repair({'inv-merged'}, 'INR');

      expect(firestore.userFields, contains(UsdTagRepairService.resolvedField));
    });

    test('a new install (empty preferences) finds it on the server and '
        'remembers it', () async {
      await service().markResolved();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      expect(service().isResolved, isFalse);

      expect(await service().checkResolved(), isTrue);
      expect(firestore.userDocReadOptions.single?.source, Source.server);
      expect(service().isResolved, isTrue);

      // Remembered here: no second server read.
      expect(await service().checkResolved(), isTrue);
      expect(firestore.userDocReadOptions, hasLength(1));
    });

    test('not answered anywhere: false, and nothing is recorded', () async {
      expect(await service().checkResolved(), isFalse);
      expect(service().isResolved, isFalse);
      expect(firestore.userFields, isNull);
    });

    test('checkResolved throws when the server cannot be reached', () async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(service().checkResolved(), throwsA(anything));
      expect(service().isResolved, isFalse);
    });

    test('a failed server write still records the answer here', () async {
      firestore.userDocWriteError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      await service().markResolved();

      expect(service().isResolved, isTrue);
    });
  });

  test('keeps its state per user', () async {
    await service().markResolved();

    final other = UsdTagRepairService(
      firestore: FakeLegacyCurrencyFirestore(uid: 'uid-2'),
      userId: 'uid-2',
      prefs: prefs,
    );
    expect(other.isResolved, isFalse);
    expect(UsdTagRepairService.prefsKeysFor('uid-1'), [
      'usd_tag_repair_resolved_uid-1',
      'usd_tag_repair_backup_uid-1',
    ]);
  });
}
