import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
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

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  final String message;
  final DateTime? retryAfter;

  CircuitBreakerOpenException({
    this.message = 'Circuit breaker is open. API is temporarily unavailable.',
    this.retryAfter,
  });

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// Conversion request for batch operations
class ConversionRequest {
  final String from;
  final double amount;
  final DateTime? date;

  const ConversionRequest({
    required this.from,
    required this.amount,
    this.date,
  });

  String get cacheKey {
    final dateStr = date != null
        ? CurrencyConversionService.formatDate(date!)
        : 'live';
    return '${dateStr}_$from';
  }
}

/// Metrics for monitoring currency conversion performance
class ConversionMetrics {
  int apiCalls = 0;
  int memoryCacheHits = 0;
  int firestoreCacheHits = 0;
  int failures = 0;
  int circuitBreakerTrips = 0;
  Duration totalApiLatency = Duration.zero;

  double get cacheHitRate {
    final total = apiCalls + memoryCacheHits + firestoreCacheHits;
    return total > 0 ? (memoryCacheHits + firestoreCacheHits) / total : 0.0;
  }

  Duration get avgApiLatency {
    return apiCalls > 0 ? totalApiLatency ~/ apiCalls : Duration.zero;
  }

  void reset() {
    apiCalls = 0;
    memoryCacheHits = 0;
    firestoreCacheHits = 0;
    failures = 0;
    circuitBreakerTrips = 0;
    totalApiLatency = Duration.zero;
  }

  Map<String, dynamic> toJson() => {
    'apiCalls': apiCalls,
    'memoryCacheHits': memoryCacheHits,
    'firestoreCacheHits': firestoreCacheHits,
    'failures': failures,
    'circuitBreakerTrips': circuitBreakerTrips,
    'cacheHitRate': cacheHitRate,
    'avgApiLatencyMs': avgApiLatency.inMilliseconds,
  };
}

/// Circuit breaker for API resilience
class CircuitBreaker {
  int _failureCount = 0;
  DateTime? _lastFailure;
  bool _isOpen = false;

  static const int _failureThreshold = 5;
  static const Duration _timeout = Duration(minutes: 1);

  bool get isOpen => _isOpen;
  int get failureCount => _failureCount;

  Future<T> execute<T>(Future<T> Function() fn) async {
    if (_isOpen) {
      final timeSinceFailure = DateTime.now().difference(_lastFailure!);
      if (timeSinceFailure > _timeout) {
        // Try to close circuit (half-open state)
        _isOpen = false;
        _failureCount = 0;
      } else {
        throw CircuitBreakerOpenException(
          retryAfter: _lastFailure!.add(_timeout),
        );
      }
    }

    try {
      final result = await fn();
      _failureCount = 0; // Reset on success
      return result;
    } catch (e) {
      _failureCount++;
      _lastFailure = DateTime.now();

      if (_failureCount >= _failureThreshold) {
        _isOpen = true;
      }
      rethrow;
    }
  }

  void reset() {
    _failureCount = 0;
    _lastFailure = null;
    _isOpen = false;
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
///
/// Features:
/// - Request coalescing: Deduplicates concurrent identical requests
/// - Circuit breaker: Fails fast when API is down
/// - Batch conversion: Optimized for multiple conversions
/// - Metrics: Comprehensive monitoring and observability
class CurrencyConversionService {
  final FirebaseFirestore _firestore;
  final String _userId;
  final http.Client _httpClient;
  final AnalyticsService? _analytics;

  // Tier 1: Memory cache (current session)
  final Map<String, double> _memoryCache = {};

  // In-flight request cache for request coalescing
  final Map<String, Future<double>> _inflightRequests = {};

  // Circuit breaker for API resilience
  final CircuitBreaker _circuitBreaker = CircuitBreaker();

  // Metrics for monitoring
  final ConversionMetrics _metrics = ConversionMetrics();

  // Memory cache size limit (LRU eviction)
  static const int _maxMemoryCacheSize = 100;

  // Primary API: Frankfurter (free, unlimited, 33 currencies)
  static const String _primaryApiBaseUrl = 'https://api.frankfurter.dev/v1';

  // Fallback API: ExchangeRate-API (free tier: 1500 requests/month, 161 currencies)
  static const String _fallbackApiBaseUrl =
      'https://api.exchangerate-api.com/v4';

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
  }) : _firestore = firestore,
       _userId = userId,
       _httpClient = httpClient ?? http.Client(),
       _analytics = analytics;

  /// Get current metrics
  ConversionMetrics get metrics => _metrics;

  /// Reset circuit breaker (for testing or manual recovery)
  void resetCircuitBreaker() => _circuitBreaker.reset();

  /// Reset metrics
  void resetMetrics() => _metrics.reset();

  /// Clear all cached exchange rates (memory + Firestore)
  ///
  /// This is a surgical cache clear that preserves:
  /// - Circuit breaker state (prevents unnecessary API failures)
  /// - Metrics (preserves performance tracking)
  /// - In-flight requests (prevents duplicate API calls)
  ///
  /// Use this instead of provider invalidation when switching currencies
  /// to avoid losing circuit breaker protection and performance metrics.
  Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear Firestore cache (batch delete for efficiency)
    try {
      final snapshot = await _exchangeRatesRef.get();
      if (snapshot.docs.isEmpty) return;

      // Firestore batch limit is 500 operations
      const batchSize = 500;
      final docs = snapshot.docs;
      var totalDeleted = 0;

      // Process in chunks of 500
      for (var i = 0; i < docs.length; i += batchSize) {
        final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        final chunk = docs.sublist(i, end);

        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        totalDeleted += chunk.length;
      }

      if (kDebugMode) {
        debugPrint('✅ Cleared $totalDeleted cached exchange rates');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to clear Firestore cache: $e');
      }
      // Don't throw - cache clear is best-effort
    }
  }

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

  /// Get exchange rate between two currencies with request coalescing
  ///
  /// [from] - Source currency code (e.g., 'USD')
  /// [to] - Target currency code (e.g., 'INR')
  /// [date] - Optional date for historical rate. If null, uses live rate.
  ///
  /// Returns exchange rate (1 unit of 'from' currency = X units of 'to' currency)
  ///
  /// Request coalescing: If multiple concurrent requests for the same rate,
  /// only one API call is made and the result is shared.
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Same currency = rate is 1.0
    if (from == to) return 1.0;

    // Create unique key for request coalescing
    final dateStr = date != null
        ? formatDate(date)
        : formatDate(DateTime.now());
    final requestKey = date != null
        ? 'historical_${dateStr}_${from}_$to'
        : 'live_${dateStr}_${from}_$to';

    // Check if request is already in-flight (request coalescing)
    if (_inflightRequests.containsKey(requestKey)) {
      return _inflightRequests[requestKey]!;
    }

    // Start new request
    final future = date != null
        ? getHistoricalRate(date, from, to)
        : getLiveRate(from, to);

    _inflightRequests[requestKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      // Clean up in-flight request
      _inflightRequests.remove(requestKey);
    }
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
    final rate = await getRate(from: from, to: to, date: date);

    return amount * rate;
  }

  /// Batch convert multiple amounts to target currency (optimized)
  ///
  /// [amounts] - Map of currency code to amount (for live rates only)
  /// [to] - Target currency code
  ///
  /// Returns map of currency code to converted amount
  ///
  /// Note: For historical rates, use batchConvertHistorical instead
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

      // Fetch rate (uses three-tier caching + request coalescing)
      final rate = await getLiveRate(from, to);
      results[from] = amount * rate;
    }

    return results;
  }

  /// Batch convert with historical rate support (optimized with deduplication)
  ///
  /// [requests] - Map of unique key to conversion request
  /// [to] - Target currency code
  ///
  /// Returns map of unique key to converted amount
  ///
  /// This method deduplicates requests by (date, currency) pair and fetches
  /// each unique rate only once, even if multiple requests need the same rate.
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    final results = <String, double>{};

    // Group by (date, currency) to deduplicate rate requests
    final uniqueRates = <String, Future<double>>{};

    for (final entry in requests.entries) {
      final key = entry.key;
      final request = entry.value;

      if (request.from == to) {
        results[key] = request.amount;
        continue;
      }

      // Create unique key for rate (date + currency pair)
      final rateKey = '${request.cacheKey}_$to';

      // Fetch rate only once per unique (date, currency) pair
      uniqueRates.putIfAbsent(rateKey, () {
        return request.date != null
            ? getHistoricalRate(request.date!, request.from, to)
            : getLiveRate(request.from, to);
      });
    }

    // Wait for all unique rates to be fetched (parallel)
    final rateEntries = await Future.wait(
      uniqueRates.entries.map((e) async {
        try {
          final rate = await e.value;
          return MapEntry(e.key, rate);
        } catch (error) {
          // Return null for failed rates (will be handled in next step)
          return MapEntry(e.key, null);
        }
      }),
      eagerError: false,
    );

    final rateMap = Map.fromEntries(
      rateEntries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!)),
    );

    // Apply rates to all requests
    for (final entry in requests.entries) {
      final key = entry.key;
      final request = entry.value;

      if (request.from == to) continue; // Already handled above

      final rateKey = '${request.cacheKey}_$to';
      final rate = rateMap[rateKey];

      if (rate != null) {
        results[key] = request.amount * rate;
      } else {
        // Rate fetch failed - throw exception with context
        throw CurrencyConversionException(
          'Failed to fetch rate for ${request.from} → $to on ${request.date ?? "today"}',
        );
      }
    }

    return results;
  }

  /// Get last known rate from cache (fallback when fresh rate unavailable)
  ///
  /// [from] - Source currency code
  /// [to] - Target currency code
  ///
  /// Returns last cached rate (any date) or null if no cache exists
  ///
  /// This is useful as a fallback when API is down or rate fetch fails
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    // Check memory cache first (any key matching currency pair)
    // Use precise matching to avoid false positives (e.g., USD_EUR vs AUSD_EUR)
    for (final entry in _memoryCache.entries) {
      // Extract currency pair from cache key format: "YYYY-MM-DD_FROM_TO" or "live_FROM_TO"
      final parts = entry.key.split('_');
      if (parts.length >= 3) {
        final cachedFrom = parts[parts.length - 2];
        final cachedTo = parts[parts.length - 1];
        if (cachedFrom == from && cachedTo == to) {
          return entry.value;
        }
      }
    }

    // Check Firestore cache (get most recent)
    try {
      final snapshot = await _exchangeRatesRef
          .where('from', isEqualTo: from)
          .where('to', isEqualTo: to)
          .orderBy('fetchedAt', descending: true)
          .limit(1)
          .get()
          .timeout(_apiTimeout);

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return data['rate'] as double;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get last known rate from Firestore: $e');
      }
    }

    return null; // No cached rate found
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
    final memKey = 'historical_${formatDate(date)}_${from}_$to';
    if (_memoryCache.containsKey(memKey)) {
      _metrics.memoryCacheHits++;
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
      _metrics.firestoreCacheHits++;
      _analytics?.logExchangeRateCacheHit(
        cacheType: 'firestore',
        rateType: 'historical',
      );
      return rate;
    }

    // 3. Fetch from API (with circuit breaker)
    final dateStr = formatDate(date);
    try {
      final startTime = DateTime.now();

      final rate = await _circuitBreaker.execute(() async {
        return await _fetchFromApiWithFallback(from: from, to: to, date: date);
      });

      final latency = DateTime.now().difference(startTime);
      _metrics.apiCalls++;
      _metrics.totalApiLatency += latency;

      _analytics?.logExchangeRateCacheHit(
        cacheType: 'api',
        rateType: 'historical',
      );

      // 4. Cache forever (historical rates never change)
      try {
        await _exchangeRatesRef
            .doc(memKey)
            .set({
              'type': 'historical',
              'date': dateStr,
              'from': from,
              'to': to,
              'rate': rate,
              'expiresAt': null, // Never expires
              'fetchedAt': FieldValue.serverTimestamp(),
            })
            .timeout(_writeTimeout);
      } on TimeoutException {
        // Offline - will sync when back online
      }

      _addToMemoryCache(memKey, rate);
      return rate;
    } on CircuitBreakerOpenException {
      _metrics.circuitBreakerTrips++;
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: 'circuit_breaker_open',
      );
      rethrow;
    } catch (e) {
      _metrics.failures++;
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
    final dateStr = formatDate(today);

    // 1. Check memory cache
    final memKey = 'live_${dateStr}_${from}_$to';
    if (_memoryCache.containsKey(memKey)) {
      _metrics.memoryCacheHits++;
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
        _metrics.firestoreCacheHits++;
        _analytics?.logExchangeRateCacheHit(
          cacheType: 'firestore',
          rateType: 'live',
        );
        return rate;
      }
    }

    // 3. Fetch from API (with circuit breaker)
    try {
      final startTime = DateTime.now();

      final rate = await _circuitBreaker.execute(() async {
        return await _fetchFromApiWithFallback(
          from: from,
          to: to,
          date: null, // Live rate
        );
      });

      final latency = DateTime.now().difference(startTime);
      _metrics.apiCalls++;
      _metrics.totalApiLatency += latency;

      _analytics?.logExchangeRateCacheHit(cacheType: 'api', rateType: 'live');

      // 4. Cache until end of day
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      try {
        await _exchangeRatesRef
            .doc(memKey)
            .set({
              'type': 'live',
              'date': dateStr,
              'from': from,
              'to': to,
              'rate': rate,
              'expiresAt': Timestamp.fromDate(endOfDay),
              'fetchedAt': FieldValue.serverTimestamp(),
            })
            .timeout(_writeTimeout);
      } on TimeoutException {
        // Offline - will sync when back online
      }

      _addToMemoryCache(memKey, rate);
      return rate;
    } on CircuitBreakerOpenException {
      _metrics.circuitBreakerTrips++;
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: from,
        toCurrency: to,
        errorType: 'circuit_breaker_open',
      );
      rethrow;
    } catch (e) {
      _metrics.failures++;
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
  ///
  /// [from] - Source currency code
  /// [to] - Target currency code
  /// [date] - Optional date for historical rates (null for live rates)
  ///
  /// Returns exchange rate
  ///
  /// Throws:
  /// - [NetworkException] if both APIs fail (shouldReport: false)
  /// - [CurrencyConversionException] for other conversion errors (shouldReport: true)
  Future<double> _fetchFromApiWithFallback({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Try primary API (Frankfurter) - NO rate limits!
    try {
      final dateStr = date != null ? formatDate(date) : 'latest';
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
        // Both APIs failed - this is a transient network issue, not an app bug
        _analytics?.logCurrencyConversionFailed(
          fromCurrency: from,
          toCurrency: to,
          errorType: 'both_apis_failed',
        );

        // Throw NetworkException instead of CurrencyConversionException
        // This will be caught by ErrorHandler and marked as shouldReport = false
        throw NetworkException(
          userMessage:
              'Unable to fetch exchange rates. Please check your internet connection.',
          technicalMessage:
              'Both currency APIs failed: primary=$primaryError, fallback=$fallbackError',
          cause: fallbackError,
          shouldReport: false, // Don't spam Crashlytics with network issues
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

      // Batch delete in chunks of 500 (Firestore limit)
      const batchSize = 500;
      for (var i = 0; i < snapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < snapshot.docs.length)
            ? i + batchSize
            : snapshot.docs.length;

        for (var j = i; j < end; j++) {
          batch.delete(snapshot.docs[j].reference);
        }

        await batch.commit().timeout(_writeTimeout);
      }
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
          if (kDebugMode) {
            debugPrint('Live cache is fresh (last refresh: $lastRefresh)');
          }
          return;
        }
      }

      // Cache is stale or never refreshed - clear it
      if (kDebugMode) {
        debugPrint('Refreshing stale live cache...');
      }
      await _clearLiveCache();

      // Update last refresh timestamp
      await prefs.setInt(lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) {
        debugPrint('Live cache refreshed successfully');
      }
    } catch (e) {
      // Non-blocking - log error but don't throw
      if (kDebugMode) {
        debugPrint('Failed to refresh live cache: $e');
      }
      _analytics?.logCurrencyConversionFailed(
        fromCurrency: 'N/A',
        toCurrency: 'N/A',
        errorType: 'cache_refresh_failed',
      );
    }
  }

  /// Format date as YYYY-MM-DD (shared utility - public for BatchCurrencyConverter)
  static String formatDate(DateTime date) {
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
CurrencyConversionService currencyConversionService(Ref ref) {
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
