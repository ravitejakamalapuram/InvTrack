// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockCollectionReference mockExchangeRatesCollection;
  late CurrencyConversionService service;
  late MockClient mockHttpClient;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockExchangeRatesCollection = MockCollectionReference();

    // Setup Firestore mock chain
    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc('test-user')).thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('exchangeRates'))
        .thenReturn(mockExchangeRatesCollection);
  });

  group('CurrencyConversionService - Same Currency', () {
    test('returns original amount when currencies are the same', () async {
      mockHttpClient = MockClient((request) async {
        fail('Should not make API call for same currency');
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      final result = await service.convert(
        amount: 1000,
        from: 'USD',
        to: 'USD',
      );

      expect(result, 1000);
    });

    test('returns rate of 1.0 when currencies are the same', () async {
      mockHttpClient = MockClient((request) async {
        fail('Should not make API call for same currency');
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      final rate = await service.getRate(from: 'USD', to: 'USD');

      expect(rate, 1.0);
    });
  });

  group('CurrencyConversionService - 3-Tier Caching', () {
    test('uses memory cache on second call (Tier 1)', () async {
      var apiCallCount = 0;

      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      mockHttpClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          '{"amount":1.0,"base":"USD","date":"2024-01-01","rates":{"INR":83.12}}',
          200,
        );
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      // First call - should hit API
      final rate1 = await service.getLiveRate('USD', 'INR');
      expect(apiCallCount, 1);
      expect(rate1, 83.12);

      // Second call - should use memory cache
      final rate2 = await service.getLiveRate('USD', 'INR');
      expect(apiCallCount, 1); // No additional API call
      expect(rate2, 83.12);
    });

    test('fetches from API when no cache exists (Tier 3)', () async {
      var apiCallCount = 0;

      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      mockHttpClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          '{"amount":1.0,"base":"USD","date":"2024-01-01","rates":{"EUR":0.92}}',
          200,
        );
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      final rate = await service.getLiveRate('USD', 'EUR');
      expect(apiCallCount, 1);
      expect(rate, 0.92);
    });
  });

  group('CurrencyConversionService - Historical Rates', () {
    test('caches historical rates forever (never expire)', () async {
      var apiCallCount = 0;

      // Mock Firestore to return no cached data initially
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      mockHttpClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          '{"amount":1.0,"base":"USD","date":"2023-01-01","rates":{"INR":82.50}}',
          200,
        );
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      final historicalDate = DateTime(2023, 1, 1);

      // First call
      final rate1 = await service.getHistoricalRate(
        historicalDate,
        'USD',
        'INR',
      );
      expect(apiCallCount, 1);
      expect(rate1, 82.50);

      // Second call - should use memory cache
      final rate2 = await service.getHistoricalRate(
        historicalDate,
        'USD',
        'INR',
      );
      expect(apiCallCount, 1); // No additional API call
      expect(rate2, 82.50);

      // Verify Firestore set was called with expiresAt: null
      verify(() => mockDocRef.set(any(
        that: predicate<Map<String, dynamic>>((data) {
          return data['type'] == 'historical' && data['expiresAt'] == null;
        }),
      ))).called(1);
    });
  });

  group('CurrencyConversionService - Live Rates', () {
    test('refreshes live rates daily', () async {
      var apiCallCount = 0;

      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      mockHttpClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          '{"amount":1.0,"base":"USD","date":"2024-01-01","rates":{"INR":83.12}}',
          200,
        );
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      // First call
      final rate1 = await service.getLiveRate('USD', 'INR');
      expect(apiCallCount, 1);
      expect(rate1, 83.12);

      // Verify Firestore set was called with expiresAt (not null)
      verify(() => mockDocRef.set(any(
        that: predicate<Map<String, dynamic>>((data) {
          return data['type'] == 'live' && data['expiresAt'] != null;
        }),
      ))).called(1);
    });
  });

  group('CurrencyConversionService - Rate Limiting', () {
    test('rate limiter allows up to 10 requests per minute', () {
      final rateLimiter = RateLimiter();

      // Should allow 10 requests
      for (var i = 0; i < 10; i++) {
        expect(rateLimiter.consumeToken(), true);
      }

      // 11th request should be denied
      expect(rateLimiter.consumeToken(), false);
    });

    test('rate limiter refills tokens over time', () async {
      final rateLimiter = RateLimiter();

      // Consume all tokens
      for (var i = 0; i < 10; i++) {
        rateLimiter.consumeToken();
      }

      expect(rateLimiter.availableTokens, 0);

      // Wait for refill (6 seconds = 1 token)
      await Future.delayed(const Duration(seconds: 7));

      expect(rateLimiter.availableTokens, greaterThan(0));
    });
  });

  group('CurrencyConversionService - Batch Conversion', () {
    test('converts multiple amounts efficiently', () async {
      var apiCallCount = 0;

      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      mockHttpClient = MockClient((request) async {
        apiCallCount++;
        final uri = request.url;

        if (uri.toString().contains('USD')) {
          return http.Response(
            '{"amount":1.0,"base":"USD","date":"2024-01-01","rates":{"INR":83.12}}',
            200,
          );
        } else if (uri.toString().contains('EUR')) {
          return http.Response(
            '{"amount":1.0,"base":"EUR","date":"2024-01-01","rates":{"INR":90.50}}',
            200,
          );
        }

        return http.Response('{}', 404);
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      final results = await service.batchConvert(
        amounts: {
          'USD': 1000,
          'EUR': 800,
          'INR': 50000,
        },
        to: 'INR',
      );

      expect(results['USD'], closeTo(83120, 1)); // 1000 * 83.12
      expect(results['EUR'], closeTo(72400, 1)); // 800 * 90.50
      expect(results['INR'], 50000); // Same currency
      expect(apiCallCount, 2); // Only 2 API calls (USD and EUR)
    });
  });

  group('CurrencyConversionService - Error Handling', () {
    test('handles invalid currency codes gracefully', () async {
      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      mockHttpClient = MockClient((request) async {
        return http.Response('{"error":"Currency not found"}', 404);
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      expect(
        () => service.getLiveRate('INVALID', 'USD'),
        throwsA(isA<CurrencyConversionException>()),
      );
    });

    test('handles network timeout gracefully', () async {
      // Mock Firestore to return no cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      mockHttpClient = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 15));
        return http.Response('{}', 200);
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      expect(
        () => service.getLiveRate('USD', 'INR'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CurrencyConversionService - Offline Support', () {
    test('uses Firestore cache when offline', () async {
      // Mock Firestore to return cached data
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();

      when(() => mockExchangeRatesCollection.doc(any()))
          .thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.data()).thenReturn({
        'type': 'live',
        'from': 'USD',
        'to': 'INR',
        'rate': 83.12,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });

      // Mock offline (API will fail)
      mockHttpClient = MockClient((request) async {
        throw Exception('Network unavailable');
      });

      service = CurrencyConversionService(
        firestore: mockFirestore,
        userId: 'test-user',
        httpClient: mockHttpClient,
      );

      // Should use Firestore cache without hitting API
      final rate = await service.getLiveRate('USD', 'INR');
      expect(rate, 83.12);
    });
  });
}

