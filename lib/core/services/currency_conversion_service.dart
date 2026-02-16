import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'currency_conversion_service.g.dart';

/// Exception thrown when currency conversion fails
class CurrencyConversionException implements Exception {
  final String message;
  final Object? originalError;

  CurrencyConversionException(this.message, [this.originalError]);

  @override
  String toString() => 'CurrencyConversionException: $message';
}

/// Service for converting currencies with three-tier caching
/// 
/// Caching Strategy:
/// - Tier 1: Memory cache (current session, instant)
/// - Tier 2: Firestore cache (persistent, offline support)
/// - Tier 3: Frankfurter API (fallback)
/// 
/// Historical rates: Cached forever (immutable)
/// Live rates: Expire end of day (auto-refresh)
class CurrencyConversionService {
  final FirebaseFirestore _firestore;
  final String _userId;
  final http.Client _httpClient;

  // Tier 1: Memory cache (current session)
  final Map<String, double> _memoryCache = {};

  // Frankfurter API base URL
  static const String _apiBaseUrl = 'https://api.frankfurter.dev/v1';

  // Write timeout for offline-first pattern
  static const Duration _writeTimeout = Duration(seconds: 5);

  CurrencyConversionService({
    required FirebaseFirestore firestore,
    required String userId,
    http.Client? httpClient,
  })  : _firestore = firestore,
        _userId = userId,
        _httpClient = httpClient ?? http.Client();

  // Collection reference for exchange rate cache
  CollectionReference<Map<String, dynamic>> get _exchangeRatesRef =>
      _firestore.collection('users').doc(_userId).collection('exchangeRates');

  /// Convert single amount from one currency to another
  /// 
  /// [amount] - Amount to convert
  /// [from] - Source currency code (e.g., 'USD')
  /// [to] - Target currency code (e.g., 'INR')
  /// [date] - Optional date for historical rate. If null, uses live rate.
  /// 
  /// Returns converted amount
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Same currency = no conversion
    if (from == to) return amount;

    // Get rate using three-tier caching
    final rate = date != null
        ? await getHistoricalRate(date, from, to)
        : await getLiveRate(from, to);

    return amount * rate;
  }

  /// Batch convert multiple amounts to target currency (optimized)
  /// 
  /// [amounts] - Map of currency code to amount
  /// [to] - Target currency code
  /// 
  /// Returns map of currency code to converted amount
  Future<Map<String, double>> batchConvert({
    required Map<String, double> amounts,
    required String to,
  }) async {
    final results = <String, double>{};

    // Group by currency, fetch rate once per currency
    for (final entry in amounts.entries) {
      final from = entry.key;
      final amount = entry.value;

      if (from == to) {
        results[from] = amount;
        continue;
      }

      // Fetch rate (uses three-tier caching)
      final rate = await getLiveRate(from, to);
      results[from] = amount * rate;
    }

    return results;
  }

  /// Preload common rates in background (don't block UI)
  ///
  /// [currencies] - Set of currency codes to preload
  /// [baseCurrency] - Target currency code
  Future<void> preloadRates(Set<String> currencies, String baseCurrency) async {
    for (final currency in currencies) {
      if (currency == baseCurrency) continue;

      // Fetch rate (will cache automatically)
      // Use unawaited to run in background
      unawaited(getLiveRate(currency, baseCurrency));
    }
  }

  /// Refresh live cache on app start (smart throttling)
  ///
  /// Only clears cache if >1 hour since last refresh
  Future<void> refreshLiveCacheOnAppStart() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefreshStr = prefs.getString('last_live_cache_refresh');

    if (lastRefreshStr != null) {
      final lastRefresh = DateTime.parse(lastRefreshStr);
      final hoursSinceRefresh = DateTime.now().difference(lastRefresh).inHours;

      if (hoursSinceRefresh < 1) {
        return; // Skip refresh (throttle)
      }
    }

    // Clear all live cache entries
    await _clearLiveCache();

    // Update last refresh time
    await prefs.setString(
      'last_live_cache_refresh',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get historical exchange rate for a specific date
  ///
  /// Historical rates are cached forever (immutable)
  ///
  /// [date] - Date for historical rate
  /// [from] - Source currency code
  /// [to] - Target currency code
  ///
  /// Returns exchange rate
  Future<double> getHistoricalRate(
    DateTime date,
    String from,
    String to,
  ) async {
    // 1. Check memory cache
    final memKey = 'historical_${_formatDate(date)}_${from}_$to';
    if (_memoryCache.containsKey(memKey)) {
      return _memoryCache[memKey]!;
    }

    // 2. Check Firestore cache
    final doc = await _exchangeRatesRef.doc(memKey).get();

    if (doc.exists) {
      final rate = doc.data()!['rate'] as double;
      _memoryCache[memKey] = rate;
      return rate;
    }

    // 3. Fetch from API
    final dateStr = _formatDate(date);
    final response = await _httpClient.get(
      Uri.parse('$_apiBaseUrl/$dateStr?base=$from&symbols=$to'),
    );

    if (response.statusCode != 200) {
      throw CurrencyConversionException(
        'Failed to fetch historical rate: ${response.statusCode}',
        response.body,
      );
    }

    final data = jsonDecode(response.body);
    final rate = data['rates'][to] as double;

    // 4. Cache forever (historical rates never change)
    try {
      await _exchangeRatesRef.doc(memKey).set({
        'type': 'historical',
        'date': dateStr,
        'from': from,
        'to': to,
        'rate': rate,
        'expiresAt': null, // Never expires
        'fetchedAt': FieldValue.serverTimestamp(),
      }).timeout(_writeTimeout);
    } on TimeoutException {
      // Offline - will sync when back online
    }

    _memoryCache[memKey] = rate;
    return rate;
  }

  /// Get live exchange rate (current/today's rate)
  ///
  /// Live rates expire at end of day
  ///
  /// [from] - Source currency code
  /// [to] - Target currency code
  ///
  /// Returns exchange rate
  Future<double> getLiveRate(String from, String to) async {
    final today = DateTime.now();
    final dateStr = _formatDate(today);

    // 1. Check memory cache
    final memKey = 'live_${dateStr}_${from}_$to';
    if (_memoryCache.containsKey(memKey)) {
      return _memoryCache[memKey]!;
    }

    // 2. Check Firestore cache (with expiration check)
    final doc = await _exchangeRatesRef.doc(memKey).get();

    if (doc.exists) {
      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      // Check if expired
      if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
        final rate = data['rate'] as double;
        _memoryCache[memKey] = rate;
        return rate;
      }
    }

    // 3. Fetch from API
    final response = await _httpClient.get(
      Uri.parse('$_apiBaseUrl/latest?base=$from&symbols=$to'),
    );

    if (response.statusCode != 200) {
      throw CurrencyConversionException(
        'Failed to fetch live rate: ${response.statusCode}',
        response.body,
      );
    }

    final data = jsonDecode(response.body);
    final rate = data['rates'][to] as double;

    // 4. Cache until end of day
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    try {
      await _exchangeRatesRef.doc(memKey).set({
        'type': 'live',
        'date': dateStr,
        'from': from,
        'to': to,
        'rate': rate,
        'expiresAt': Timestamp.fromDate(endOfDay),
        'fetchedAt': FieldValue.serverTimestamp(),
      }).timeout(_writeTimeout);
    } on TimeoutException {
      // Offline - will sync when back online
    }

    _memoryCache[memKey] = rate;
    return rate;
  }

  /// Clear all live cache entries
  Future<void> _clearLiveCache() async {
    try {
      // Query all live cache entries
      final snapshot = await _exchangeRatesRef
          .where('type', isEqualTo: 'live')
          .get()
          .timeout(_writeTimeout);

      // Batch delete
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(_writeTimeout);
    } on TimeoutException {
      // Offline - will sync when back online
    }

    // Clear memory cache
    _memoryCache.clear();
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
    _memoryCache.clear();
  }
}

/// Provider for CurrencyConversionService
///
/// Provides access to currency conversion with three-tier caching
@riverpod
CurrencyConversionService currencyConversionService(
  CurrencyConversionServiceRef ref,
) {
  final firestore = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    throw Exception('User must be authenticated to use currency conversion');
  }

  final service = CurrencyConversionService(
    firestore: firestore,
    userId: userId,
    httpClient: http.Client(),
  );

  // Dispose when provider is destroyed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

