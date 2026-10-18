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

/// A14 / #759: AED and SAR pegs as fallback, and numeric rate parsing.
void main() {
  late _MockFirestore firestore;
  late _MockDoc docRef;
  late _MockSnap snap;

  CurrencyConversionService build(
    http.Response Function(Uri) respond, {
    bool cached = false,
    Map<String, dynamic>? cachedData,
  }) {
    final users = _MockCol();
    final userDoc = _MockDoc();
    final rates = _MockCol();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('u')).thenReturn(userDoc);
    when(() => userDoc.collection('exchangeRates')).thenReturn(rates);
    when(() => rates.doc(any())).thenReturn(docRef);
    when(() => docRef.get()).thenAnswer((_) async => snap);
    when(() => docRef.set(any())).thenAnswer((_) async {});
    when(() => snap.exists).thenReturn(cached);
    if (cachedData != null) when(() => snap.data()).thenReturn(cachedData);
    return CurrencyConversionService(
      firestore: firestore,
      userId: 'u',
      httpClient: MockClient((r) async => respond(r.url)),
    );
  }

  // Frankfurter has no AED/SAR: 404 for any URL that mentions them.
  http.Response frankfurter(Uri u) {
    final s = u.toString();
    if (s.contains('AED') || s.contains('SAR')) {
      return http.Response('{"message":"not found"}', 404);
    }
    // The latest and the dated USD->INR rates differ, so a test can tell
    // which one was fetched.
    if (s.contains('base=USD&symbols=INR')) {
      final rate = u.path.endsWith('/2024-01-15') ? 80.0 : 83.5;
      return http.Response('{"rates":{"INR":$rate}}', 200);
    }
    return http.Response('nope', 500);
  }

  setUp(() {
    firestore = _MockFirestore();
    docRef = _MockDoc();
    snap = _MockSnap();
  });

  group('AED/SAR USD pegs', () {
    test('AED -> INR live = USDINR / 3.6725', () async {
      final s = build(frankfurter);
      expect(await s.getLiveRate('AED', 'INR'), closeTo(83.5 / 3.6725, 1e-6));
    });

    test('SAR -> INR historical = USDINR / 3.75', () async {
      final s = build(frankfurter);
      final r = await s.getHistoricalRate(DateTime(2024, 1, 15), 'SAR', 'INR');
      expect(r, closeTo(80.0 / 3.75, 1e-6));
    });

    test('INR -> AED = 3.6725 / USDINR', () async {
      final s = build(frankfurter);
      expect(await s.getLiveRate('INR', 'AED'), closeTo(3.6725 / 83.5, 1e-6));
    });

    test('AED -> SAR = 3.75 / 3.6725 and needs no rate lookup', () async {
      final s = build(frankfurter);
      final r = await s.getHistoricalRate(DateTime(2024, 1, 15), 'AED', 'SAR');
      expect(r, closeTo(3.75 / 3.6725, 1e-6));
    });

    test('USD -> AED = 3.6725 and USD -> SAR = 3.75', () async {
      final s = build(frankfurter);
      expect(await s.getLiveRate('USD', 'AED'), closeTo(3.6725, 1e-6));
      expect(await s.getLiveRate('USD', 'SAR'), closeTo(3.75, 1e-6));
    });

    test('pairs made only of pegs and USD make no request at all', () async {
      var requests = 0;
      final s = build((_) {
        requests++;
        return http.Response('nope', 500);
      });
      expect(await s.getLiveRate('AED', 'SAR'), closeTo(3.75 / 3.6725, 1e-6));
      expect(await s.getLiveRate('USD', 'AED'), closeTo(3.6725, 1e-6));
      expect(
        await s.getHistoricalRate(DateTime(2024, 1, 15), 'SAR', 'USD'),
        closeTo(1 / 3.75, 1e-6),
      );
      expect(requests, 0);
    });

    test('a zero or negative USD quote is rejected, not divided by', () async {
      // No Frankfurter rate for AED; the USD cross for INR is bad.
      http.Response badCross(double quote) =>
          http.Response('{"rates":{"INR":$quote}}', 200);
      for (final quote in [0.0, -83.5]) {
        final s = build(
          (u) => u.toString().contains('AED')
              ? http.Response('nope', 404)
              : badCross(quote),
        );
        await expectLater(s.getLiveRate('AED', 'INR'), throwsA(anything));
        await expectLater(s.getLiveRate('INR', 'AED'), throwsA(anything));
      }
    });
  });

  group('numeric rate parsing', () {
    test('integer API rate parses', () async {
      final s = build((_) => http.Response('{"rates":{"INR":83}}', 200));
      expect(await s.getLiveRate('USD', 'INR'), 83.0);
    });

    test('integer cached historical rate parses', () async {
      final s = build(
        (_) => fail('no network expected'),
        cached: true,
        cachedData: {'rate': 83},
      );
      expect(
        await s.getHistoricalRate(DateTime(2024, 1, 15), 'USD', 'INR'),
        83.0,
      );
    });

    test('integer cached live rate parses', () async {
      final s = build(
        (_) => fail('no network expected'),
        cached: true,
        cachedData: {
          'rate': 83,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 5)),
          ),
        },
      );
      expect(await s.getLiveRate('USD', 'INR'), 83.0);
    });
  });
}
