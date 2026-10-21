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

/// A14 / #759: the in-memory rate cache evicts the least recently USED entry
/// (as its comment says), not the oldest inserted one.
void main() {
  test('a rate that keeps being read survives a full cache', () async {
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

    var apiCalls = 0;
    final service = CurrencyConversionService(
      firestore: firestore,
      userId: 'u',
      httpClient: MockClient((_) async {
        apiCalls++;
        return http.Response('{"rates":{"INR":83.5}}', 200);
      }),
    );

    final first = DateTime(2020, 1, 1);
    // Fill the 100-entry cache; `first` is the oldest.
    for (var i = 0; i < 100; i++) {
      await service.getHistoricalRate(
        first.add(Duration(days: i)),
        'USD',
        'INR',
      );
    }
    expect(apiCalls, 100);

    // Read the oldest entry again (cache hit), then add one more entry.
    await service.getHistoricalRate(first, 'USD', 'INR');
    await service.getHistoricalRate(DateTime(2021, 1, 1), 'USD', 'INR');
    expect(apiCalls, 101);

    // The recently read entry must still be cached.
    await service.getHistoricalRate(first, 'USD', 'INR');
    expect(apiCalls, 101);
  });
}
