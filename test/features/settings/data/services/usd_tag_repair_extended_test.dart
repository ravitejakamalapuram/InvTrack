// A109: older imports and restores also tagged goals, expected payments,
// investments with no cash flows yet and some cash flows of otherwise
// base-currency investments as US dollars. The A04 repair only looked at
// investments whose every cash flow was in US dollars, so these stayed
// converted at the dollar rate (an INR 5,00,000 goal read as about
// INR 4 crore). They are now flagged too, unticked, and only the documents
// in US dollars change.
import 'dart:convert';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore()
      // A goal from an old goal CSV without a currency column.
      ..put('goals', 'g1', {
        'name': 'House',
        'targetAmount': 500000.0,
        'currency': 'USD',
      })
      ..put('archivedGoals', 'g2', {
        'name': 'Old car',
        'targetAmount': 300000.0,
        'currency': 'USD',
      })
      ..put('goals', 'g-inr', {
        'name': 'Emergency fund',
        'targetAmount': 200000.0,
        'currency': 'INR',
      })
      // An INR investment whose expected payment came back from an old
      // backup tagged USD.
      ..put('investments', 'inv-p2p', {'name': 'P2P loan', 'currency': 'INR'})
      ..put('cashflows', 'cf-p1', {
        'investmentId': 'inv-p2p',
        'type': 'INVEST',
        'amount': 100000.0,
        'currency': 'INR',
      })
      ..put('expectedCashFlows', 'e1', {
        'investmentId': 'inv-p2p',
        'amount': 25000.0,
        'currency': 'USD',
      })
      // No cash flows yet: the next one would inherit US dollars.
      ..put('investments', 'inv-empty', {'name': 'New FD', 'currency': 'USD'})
      // Partly in US dollars, the rest in the base currency.
      ..put('investments', 'inv-mixed', {
        'name': 'Bond ladder',
        'currency': 'INR',
      })
      ..put('cashflows', 'cf-u', {
        'investmentId': 'inv-mixed',
        'type': 'INVEST',
        'amount': 100000.0,
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-r', {
        'investmentId': 'inv-mixed',
        'type': 'INVEST',
        'amount': 50000.0,
        'currency': 'INR',
      })
      // US dollars and euros: really multi-currency, never flagged.
      ..put('investments', 'inv-eur', {'name': 'Euro bond', 'currency': 'USD'})
      ..put('cashflows', 'cf-e1', {
        'investmentId': 'inv-eur',
        'type': 'INVEST',
        'amount': 1000.0,
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-e2', {
        'investmentId': 'inv-eur',
        'type': 'RETURN',
        'amount': 1100.0,
        'currency': 'EUR',
      })
      // Merged before A03: all US dollars, and its expected payment too.
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
      ..put('expectedCashFlows', 'e2', {
        'investmentId': 'inv-merged',
        'amount': 40000.0,
        'currency': 'USD',
      });
  });

  group('findCandidates', () {
    test('with base INR flags goals, expected payments, empty and partly '
        'US dollar investments, and only merged ones start ticked', () async {
      final found = await service().findCandidates('INR');

      expect(
        [
          for (final c in found)
            (
              c.id,
              c.kind,
              c.cashFlowCount,
              c.usdCashFlowCount,
              c.expectedPaymentCount,
              c.isArchived,
              c.tickedByDefault,
            ),
        ],
        [
          ('partly:inv-mixed', UsdTagKind.partlyUsd, 2, 1, 0, false, false),
          ('inv-merged', UsdTagKind.allUsd, 1, 1, 1, false, true),
          ('empty:inv-empty', UsdTagKind.noCashFlows, 0, 0, 0, false, false),
          ('partly:inv-p2p', UsdTagKind.partlyUsd, 1, 0, 1, false, false),
          ('goal:g1', UsdTagKind.goal, 0, 0, 0, false, false),
          ('goal:g2', UsdTagKind.goal, 0, 0, 0, true, false),
        ],
      );
      expect(found.map((c) => c.name), [
        'Bond ladder',
        'Merged FD',
        'New FD',
        'P2P loan',
        'House',
        'Old car',
      ]);
    });

    test('with base USD flags nothing and reads nothing', () async {
      expect(await service().findCandidates('USD'), isEmpty);
      expect(firestore.readOptions, isEmpty);
    });

    test('never flags the expected payments of sample investments', () async {
      await prefs.setStringList('sample_data_investment_ids', ['inv-p2p']);

      final found = await service().findCandidates('INR');

      expect(found.map((c) => c.id), isNot(contains('partly:inv-p2p')));
    });
  });

  // A04 shipped in v3.73.5 and listed only investments all in US dollars.
  // Users who answered it are asked once more. All US dollar investments
  // are listed again, because A04 skipped those that had no cash flows
  // then, but start unticked, because the user may have kept them.
  group('after the A04 answer', () {
    test('the new kinds are listed, and all US dollar investments are '
        'listed unticked', () async {
      await prefs.setBool('usd_tag_repair_resolved_${firestore.uid}', true);

      expect(service().isResolved, isFalse);
      expect(service().answeredAllUsd, isTrue);
      final found = await service().findCandidates('INR');

      expect(
        [for (final c in found) (c.id, c.tickedByDefault)],
        [
          ('partly:inv-mixed', false),
          ('inv-merged', false),
          ('empty:inv-empty', false),
          ('partly:inv-p2p', false),
          ('goal:g1', false),
          ('goal:g2', false),
        ],
      );
    });

    test('an A04 answer on another device is remembered here, and is not '
        'the answer to the new question', () async {
      firestore.userFields = {
        UsdTagRepairService.resolvedField: DateTime.utc(2026, 10, 4),
      };

      expect(await service().checkResolved(), isFalse);
      expect(service().answeredAllUsd, isTrue);
      expect(service().isResolved, isFalse);
      final merged = (await service().findCandidates(
        'INR',
      )).singleWhere((c) => c.id == 'inv-merged');
      expect(merged.tickedByDefault, isFalse);
    });

    test('the new answer is recorded on this device and for the '
        'account', () async {
      await service().markResolved();

      expect(service().isResolved, isTrue);
      expect(service().answeredAllUsd, isTrue);
      expect(
        firestore.userFields!.keys,
        containsAll([
          UsdTagRepairService.resolvedField,
          UsdTagRepairService.extendedResolvedField,
        ]),
      );
    });

    test('the new answer is removed with the account', () {
      expect(
        UsdTagRepairService.prefsKeysFor('uid-1'),
        contains('usd_tag_repair_extended_resolved_uid-1'),
      );
    });
  });

  group('repair', () {
    test('a ticked goal changes to the base currency and keeps its target '
        'to the paisa', () async {
      final written = await service().repair({'goal:g1'}, 'INR');

      expect(written, (documents: 1, investments: 0, goals: 1));
      expect(currencyOf('goals', 'g1'), 'INR');
      expect(firestore.stored('goals', 'g1')!['targetAmount'], 500000.00);
      // Not ticked: untouched.
      expect(currencyOf('archivedGoals', 'g2'), 'USD');
    });

    test('a ticked expected payment changes and keeps its amount', () async {
      final written = await service().repair({'partly:inv-p2p'}, 'INR');

      expect(written, (documents: 1, investments: 1, goals: 0));
      expect(currencyOf('expectedCashFlows', 'e1'), 'INR');
      expect(firestore.stored('expectedCashFlows', 'e1')!['amount'], 25000.00);
      expect(currencyOf('cashflows', 'cf-p1'), 'INR');
    });

    test('an all US dollar investment takes its expected payments with '
        'it', () async {
      final written = await service().repair({'inv-merged'}, 'INR');

      expect(written, (documents: 3, investments: 1, goals: 0));
      expect(currencyOf('investments', 'inv-merged'), 'INR');
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
      expect(currencyOf('expectedCashFlows', 'e2'), 'INR');
      expect(firestore.stored('expectedCashFlows', 'e2')!['amount'], 40000.00);
    });

    test('an investment with no cash flows changes, so new cash flows are '
        'in the base currency', () async {
      final written = await service().repair({'empty:inv-empty'}, 'INR');

      expect(written, (documents: 1, investments: 1, goals: 0));
      expect(currencyOf('investments', 'inv-empty'), 'INR');
    });

    test('a partly US dollar investment changes only its US dollar cash '
        'flow', () async {
      final before = Map.of(firestore.stored('cashflows', 'cf-r')!);

      final written = await service().repair({'partly:inv-mixed'}, 'INR');

      expect(written, (documents: 1, investments: 1, goals: 0));
      expect(currencyOf('cashflows', 'cf-u'), 'INR');
      expect(firestore.stored('cashflows', 'cf-u')!['amount'], 100000.00);
      expect(firestore.stored('cashflows', 'cf-r'), before);
    });

    test('an investment that changed kind since the question is left '
        'alone', () async {
      // The user saw "1 of 2 cash flows in US dollars" and ticked it; then
      // another device tagged the other cash flow USD as well.
      firestore.stored('cashflows', 'cf-r')!['currency'] = 'USD';

      final written = await service().repair({'partly:inv-mixed'}, 'INR');

      expect(written, (documents: 0, investments: 0, goals: 0));
      expect(currencyOf('cashflows', 'cf-u'), 'USD');
      expect(service().hasBackup, isFalse);
    });

    test('a multi-currency investment is never changed, even when '
        'asked', () async {
      final written = await service().repair({
        'inv-eur',
        'partly:inv-eur',
      }, 'INR');

      expect(written, (documents: 0, investments: 0, goals: 0));
      expect(currencyOf('investments', 'inv-eur'), 'USD');
      expect(currencyOf('cashflows', 'cf-e1'), 'USD');
    });
  });

  group('undo', () {
    test('puts US dollars back on the goal, the expected payment, the empty '
        'investment and the partly US dollar cash flow', () async {
      final s = service();
      await s.repair({
        'goal:g1',
        'partly:inv-p2p',
        'empty:inv-empty',
        'partly:inv-mixed',
      }, 'INR');

      final backup =
          jsonDecode(prefs.getString('usd_tag_repair_backup_${firestore.uid}')!)
              as List;
      expect(
        [for (final e in backup) (e['c'], e['id'], e['inv'])],
        unorderedEquals([
          ('goals', 'g1', 'goal:g1'),
          ('expectedCashFlows', 'e1', 'inv-p2p'),
          ('investments', 'inv-empty', 'inv-empty'),
          ('cashflows', 'cf-u', 'inv-mixed'),
        ]),
      );
      expect(s.backedUpInvestmentCount, 3);
      expect(s.backedUpGoalCount, 1);

      expect(await s.undo(), 4);

      expect(currencyOf('goals', 'g1'), 'USD');
      expect(currencyOf('expectedCashFlows', 'e1'), 'USD');
      expect(currencyOf('investments', 'inv-empty'), 'USD');
      expect(currencyOf('cashflows', 'cf-u'), 'USD');
      expect(currencyOf('cashflows', 'cf-r'), 'INR');
      expect(firestore.stored('goals', 'g1')!['targetAmount'], 500000.00);
      expect(s.hasBackup, isFalse);
    });

    test('restores a goal archived after the fix', () async {
      await service().repair({'goal:g1'}, 'INR');
      firestore.data.putIfAbsent('archivedGoals', () => {})['g1'] = firestore
          .data['goals']!
          .remove('g1')!;

      expect(await service().undo(), 1);

      expect(currencyOf('archivedGoals', 'g1'), 'USD');
      expect(firestore.stored('goals', 'g1'), isNull);
    });
  });
}
