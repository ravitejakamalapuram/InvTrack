// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

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

/// Crash 14d05221: preloadRates runs getLiveRate in the background. When
/// Firestore is unavailable the failure escaped as an uncaught async error.
void main() {
  test('preloadRates swallows a Firestore failure in the background', () async {
    final firestore = _MockFirestore();
    final users = _MockCol();
    final userDoc = _MockDoc();
    final rates = _MockCol();
    final doc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('u')).thenReturn(userDoc);
    when(() => userDoc.collection('exchangeRates')).thenReturn(rates);
    when(() => rates.doc(any())).thenReturn(doc);
    when(() => doc.get()).thenAnswer(
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      ),
    );

    final service = CurrencyConversionService(
      firestore: firestore,
      userId: 'u',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );

    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      await service.preloadRates({'USD'}, 'INR');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (e, _) => uncaught.add(e));

    expect(uncaught, isEmpty);
  });
}
