import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inv_tracker/core/analytics/analytics_service.dart';
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

/// Token bucket rate limiter for API calls
///
/// Prevents excessive API calls by limiting to [_maxTokens] calls per minute
/// Tokens refill at rate of 1 per [_refillInterval]
class RateLimiter {
  int _availableTokens;
  DateTime _lastRefillTime;

  static const int _maxTokens = 10;
  static const Duration _refillInterval = Duration(seconds: 6); // 10 tokens/min

  RateLimiter()
      : _availableTokens = _maxTokens,
        _lastRefillTime = DateTime.now();

  /// Check if a request can be made (without consuming token)
  bool canMakeRequest() {
    _refillTokens();
    return _availableTokens > 0;
  }

  /// Consume a token for an API call
  ///
  /// Returns true if token was consumed, false if no tokens available
  bool consumeToken() {
    _refillTokens();
    if (_availableTokens > 0) {
      _availableTokens--;
      return true;
    }
    return false;
  }

  /// Refill tokens based on elapsed time
  void _refillTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefillTime);
    final tokensToAdd =
        (elapsed.inSeconds / _refillInterval.inSeconds).floor();

    if (tokensToAdd > 0) {
      _availableTokens = min(_maxTokens, _availableTokens + tokensToAdd);
      _lastRefillTime = now;
    }
  }

  /// Get current number of available tokens (for debugging/monitoring)
  int get availableTokens {
    _refillTokens();
    return _availableTokens;
  }
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
  final AnalyticsService? _analytics;

  // Tier 1: Memory cache (current session)
  final Map<String, double> _memoryCache = {};

  // Memory cache size limit (LRU eviction)
  static const int _maxMemoryCacheSize = 100;

  // Rate limiter for API calls
  final RateLimiter _rateLimiter = RateLimiter();

  // Primary API: Frankfurter (free, unlimited, 33 currencies)
  static const String _primaryApiBaseUrl = 'https://api.frankfurter.dev/v1';

  // Fallback API: ExchangeRate-API (free tier: 1500 requests/month, 161 currencies)
  static const String _fallbackApiBaseUrl = 'https://api.exchangerate-api.com/v4';

  // Write timeout for offline-first pattern
  static const Duration _writeTimeout = Duration(seconds: 5);

  // API timeout for network calls
  static const Duration _apiTimeout = Duration(seconds: 10);

  // Live cache staleness threshold (refresh if older than 1 hour)
  static const Duration _liveCacheStaleness = Duration(hours: 1);

  CurrencyConversionService({
    required FirebaseFirestore firestore,
    required String userId,
    http.Client? httpClient,
    AnalyticsService? analytics,
  })  : _firestore = firestore,
        _userId = userId,
        _httpClient = httpClient ?? http.Client(),
        _analytics = analytics;

  // Collection reference for exchange rate cache
  CollectionReference<Map<String, dynamic>> get _exchangeRatesRef =>
      _firestore.collection('users').doc(_userId).collection('exchangeRates');

  /// Add entry to memory cache with LRU eviction
  void _addToMemoryCache(String key, double value) {
    // If cache is full, remove oldest entry (first entry in map)
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }

    _memoryCache[key] = value;
  }

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
      _analytics?.logExchangeRateCacheHit(
        cacheType: 'memory',
        rateType: 'historical',
      );
      return _memoryCache[memKey]!;
    }

    // 2. Check Firestore cache
    final doc = await _exchangeRatesRef.doc(memKey).get();

    if (doc.exists) {
      final rate = doc.data()!['rate'] as double;
      _addToMemoryCache(memKey, rate);
      _analytics?.logExchangeRateCacheHit(
        cacheType: 'firestore',
        rateType: 'historical',
      );
      return rate;
    }

    // 3. Fetch from API (with fallback)
    final dateStr = _formatDate(date);
    try {
      final rate = await _fetchFromApiWithFallback(
        from: from,
        to: to,
        date: date,
      );

      _analytics?.logExchangeRateCacheHit(
        cacheType: 'api',
        rateType: 'historical',
      );

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

      _addToMemoryCache(memKey, rate);
      return rate;
    } catch (e) {
      // Network or parsing error
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: e is TimeoutException ? 'timeout' : 'network',
      );
      rethrow;
    }
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
      _analytics?.logExchangeRateCacheHit(
        cacheType: 'memory',
        rateType: 'live',
      );
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
        _addToMemoryCache(memKey, rate);
        _analytics?.logExchangeRateCacheHit(
          cacheType: 'firestore',
          rateType: 'live',
        );
        return rate;
      }
    }

    // 3. Fetch from API (with fallback)
    try {
      final rate = await _fetchFromApiWithFallback(
        from: from,
        to: to,
        date: null, // Live rate
      );

      _analytics?.logExchangeRateCacheHit(
        cacheType: 'api',
        rateType: 'live',
      );

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

      _addToMemoryCache(memKey, rate);
      return rate;
    } catch (e) {
      // Network or parsing error
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: e is TimeoutException ? 'timeout' : 'network',
      );
      rethrow;
    }
  }

  /// Fetch exchange rate from API with fallback support
  ///
  /// Tries primary API (Frankfurter) first, falls back to ExchangeRate-API on failure
  /// Uses rate limiter to prevent excessive API calls
  ///
  /// [from] - Source currency code
  /// [to] - Target currency code
  /// [date] - Optional date for historical rates (null for live rates)
  ///
  /// Returns exchange rate
  /// Throws [CurrencyConversionException] if rate limit hit or both APIs fail
  Future<double> _fetchFromApiWithFallback({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Check rate limiter
    if (!_rateLimiter.consumeToken()) {
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: 'rate_limit_hit',
      );
      throw CurrencyConversionException(
        'Rate limit exceeded. Please wait a moment and try again.',
      );
    }

    // Try primary API (Frankfurter)
    try {
      final dateStr = date != null ? _formatDate(date) : 'latest';
      final url = '$_primaryApiBaseUrl/$dateStr?base=$from&symbols=$to';

      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['rates'][to] as double;
      }

      // Non-200 status, try fallback
      throw CurrencyConversionException(
        'Primary API returned ${response.statusCode}',
      );
    } catch (primaryError) {
      // Log primary API failure
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: 'primary_api_failed',
      );

      // Try fallback API (ExchangeRate-API)
      try {
        // Note: ExchangeRate-API free tier doesn't support historical rates
        // Only use for live rates
        if (date != null) {
          // No fallback for historical rates
          throw CurrencyConversionException(
            'Historical rates not available from fallback API',
            primaryError,
          );
        }

        final url = '$_fallbackApiBaseUrl/latest/$from';
        final response = await _httpClient
            .get(Uri.parse(url))
            .timeout(_apiTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rates = data['rates'] as Map<String, dynamic>;

          if (!rates.containsKey(to)) {
            throw CurrencyConversionException(
              'Currency $to not supported by fallback API',
            );
          }

          return (rates[to] as num).toDouble();
        }

        throw CurrencyConversionException(
          'Fallback API returned ${response.statusCode}',
        );
      } catch (fallbackError) {
        // Both APIs failed
        _analytics?.logCurrencyConversionFailed(
          fromCurrency: from,
          toCurrency: to,
          errorType: 'both_apis_failed',
        );

        throw CurrencyConversionException(
          'Both primary and fallback APIs failed',
          fallbackError,
        );
      }
    }
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

  /// Refresh live cache if stale (older than 1 hour)
  ///
  /// Called on app start to ensure fresh rates for today's transactions
  /// Non-blocking - failures are logged but don't throw
  Future<void> refreshLiveCacheIfStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshKey = 'currency_live_cache_last_refresh';
      final lastRefreshMs = prefs.getInt(lastRefreshKey);

      if (lastRefreshMs != null) {
        final lastRefresh = DateTime.fromMillisecondsSinceEpoch(lastRefreshMs);
        final now = DateTime.now();

        if (now.difference(lastRefresh) < _liveCacheStaleness) {
          // Cache is fresh, no need to refresh
          debugPrint('Live cache is fresh (last refresh: $lastRefresh)');
          return;
        }
      }

      // Cache is stale or never refreshed - clear it
      debugPrint('Refreshing stale live cache...');
      await _clearLiveCache();

      // Update last refresh timestamp
      await prefs.setInt(lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('Live cache refreshed successfully');
    } catch (e) {
      // Non-blocking - log error but don't throw
      debugPrint('Failed to refresh live cache: $e');
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: 'N/A',
        toCurrency: 'N/A',
        errorType: 'cache_refresh_failed',
      );
    }
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
    analytics: ref.watch(analyticsServiceProvider),
  );

  // Dispose when provider is destroyed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

