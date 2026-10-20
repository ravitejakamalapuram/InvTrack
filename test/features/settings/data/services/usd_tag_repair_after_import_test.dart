// A110: a restore or import after the question was answered can bring US
// dollar tags back. The scan can be limited to what the import wrote, and
// investments the user chose to keep are not listed again.
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

  void putInvestment(String id, String currency) {
    firestore
      ..put('investments', id, {'name': 'Inv $id', 'currency': currency})
      ..put('cashflows', 'cf-$id', {
        'investmentId': id,
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

  test('question answered earlier: a restored all-USD investment is listed '
      'when the scan is limited to what the import wrote', () async {
    final s = service();
    await s.markResolved();
    putInvestment('x', 'USD');

    final found = await s.findCandidates('INR', onlyOwners: {'x'});

    expect(found.map((c) => c.id), ['x']);
  });

  test('an investment kept as USD earlier (same id) is not listed', () async {
    final s = service();
    await s.markResolved();
    await s.markKept(['x']);
    putInvestment('x', 'USD');

    expect(await s.findCandidates('INR', onlyOwners: {'x'}), isEmpty);
  });

  test('a backup that is all INR lists nothing, and USD documents the import '
      'did not write are left alone', () async {
    final s = service();
    await s.markResolved();
    putInvestment('restored', 'INR');
    putInvestment('untouched', 'USD');

    expect(await s.findCandidates('INR', onlyOwners: {'restored'}), isEmpty);
  });

  test('the Keep list is removed with the other keys on account deletion', () {
    expect(
      UsdTagRepairService.prefsKeysFor('u1'),
      contains('usd_tag_repair_kept_u1'),
    );
  });

  test('Keep is remembered per user', () async {
    await service().markKept(['x']);
    final other = UsdTagRepairService(
      firestore: firestore,
      userId: 'someone-else',
      prefs: prefs,
    );
    expect(other.keptIds, isEmpty);
  });
}
