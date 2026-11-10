// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCol extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnap extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnap extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

/// A14 / #759: a conversion that used a cached or last-known rate says so
/// (`isApproximate`) when that rate is older than 24 hours; a fresh one does
/// not.
void main() {
  final now = DateTime(2026, 10, 21, 12);

  /// Service whose Firestore has no document for any id and whose last-known
  /// query returns [stored] (or nothing). The HTTP API always answers 83.5.
  CurrencyConversionService build({
    Map<String, dynamic>? stored,
    DateTime Function()? clock,
  }) {
    final firestore = _MockFirestore();
    final users = _MockCol();
    final userDoc = _MockDoc();
    final rates = _MockCol();
    final doc = _MockDoc();
    final snap = _MockSnap();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('u')).thenReturn(userDoc);
    when(() => userDoc.collection('exchangeRates')).thenReturn(rates);
    when(() => rates.doc(any())).thenReturn(doc);
    when(() => doc.get()).thenAnswer((_) async => snap);
    when(() => doc.set(any())).thenAnswer((_) async {});
    when(() => snap.exists).thenReturn(false);

    final q1 = _MockQuery();
    final q2 = _MockQuery();
    final q3 = _MockQuery();
    final q4 = _MockQuery();
    final querySnap = _MockQuerySnap();
    when(
      () => rates.where('from', isEqualTo: any(named: 'isEqualTo')),
    ).thenReturn(q1);
    when(
      () => q1.where('to', isEqualTo: any(named: 'isEqualTo')),
    ).thenReturn(q2);
    when(() => q2.orderBy('fetchedAt', descending: true)).thenReturn(q3);
    when(() => q3.limit(1)).thenReturn(q4);
    when(() => q4.get()).thenAnswer((_) async => querySnap);
    if (stored == null) {
      when(() => querySnap.docs).thenReturn([]);
    } else {
      final queryDoc = _MockQueryDoc();
      when(queryDoc.data).thenReturn(stored);
      when(() => querySnap.docs).thenReturn([queryDoc]);
    }

    return CurrencyConversionService(
      firestore: firestore,
      userId: 'u',
      clock: clock,
      httpClient: MockClient(
        (_) async => http.Response('{"rates":{"INR":83.5}}', 200),
      ),
    );
  }

  test('a live rate fetched today is not approximate', () async {
    final service = build();
    await service.getLiveRate('USD', 'INR');

    final lookup = await service.getLastKnownRateResult(from: 'USD', to: 'INR');

    expect(lookup!.rate, 83.5);
    expect(lookup.isApproximate, isFalse);
  });

  test(
    'the same cached rate is approximate once it is over 24 hours old',
    () async {
      final service = build(
        clock: () => DateTime.now().add(const Duration(days: 3)),
      );
      await service.getLiveRate('USD', 'INR');

      final lookup = await service.getLastKnownRateResult(
        from: 'USD',
        to: 'INR',
      );

      expect(lookup!.rate, 83.5);
      expect(lookup.isApproximate, isTrue);
    },
  );

  test(
    'a historical rate from another date is the nearest-date fallback',
    () async {
      final service = build();
      await service.getHistoricalRate(DateTime(2020, 1, 1), 'USD', 'INR');

      final lookup = await service.getLastKnownRateResult(
        from: 'USD',
        to: 'INR',
      );

      expect(lookup!.rate, 83.5);
      expect(lookup.isApproximate, isTrue);
    },
  );

  test('a stored live rate fetched 2 hours ago is fresh', () async {
    final service = build(
      clock: () => now,
      stored: {
        'type': 'live',
        'rate': 82.0,
        'fetchedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
      },
    );

    final lookup = await service.getLastKnownRateResult(from: 'USD', to: 'INR');

    expect(lookup!.rate, 82.0);
    expect(lookup.isApproximate, isFalse);
  });

  test('a stored live rate fetched 30 hours ago is approximate', () async {
    final service = build(
      clock: () => now,
      stored: {
        'type': 'live',
        'rate': 82.0,
        'fetchedAt': Timestamp.fromDate(
          now.subtract(const Duration(hours: 30)),
        ),
      },
    );

    final lookup = await service.getLastKnownRateResult(from: 'USD', to: 'INR');

    expect(lookup!.rate, 82.0);
    expect(lookup.isApproximate, isTrue);
  });

  test(
    'a stored historical rate counts by its own date, not by fetch time',
    () async {
      final service = build(
        clock: () => now,
        stored: {
          'type': 'historical',
          'date': '2024-03-01',
          'rate': 80.0,
          'fetchedAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
        },
      );

      final lookup = await service.getLastKnownRateResult(
        from: 'USD',
        to: 'INR',
      );

      expect(lookup!.rate, 80.0);
      expect(lookup.isApproximate, isTrue);
    },
  );

  test('no cached rate gives null', () async {
    final service = build(clock: () => now);

    expect(
      await service.getLastKnownRateResult(from: 'USD', to: 'INR'),
      isNull,
    );
  });

  test('getLastKnownRate still returns the plain rate', () async {
    final service = build(
      clock: () => now,
      stored: {
        'type': 'live',
        'rate': 82.0,
        'fetchedAt': Timestamp.fromDate(now),
      },
    );

    expect(await service.getLastKnownRate(from: 'USD', to: 'INR'), 82.0);
  });
}
