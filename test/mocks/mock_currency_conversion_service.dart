import 'package:inv_tracker/core/services/currency_conversion_service.dart';

/// Mock implementation of CurrencyConversionService for testing
class MockCurrencyConversionService implements CurrencyConversionService {
  bool clearCacheCalled = false;
  int clearCacheCallCount = 0;

  @override
  Future<void> clearCache() async {
    clearCacheCalled = true;
    clearCacheCallCount++;
    // No-op for tests - doesn't require Firebase
  }

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Simple mock conversion: 1 USD = 83 INR, 1 EUR = 90 INR, etc.
    if (from == to) return amount;

    // Mock exchange rates to INR
    const rates = {
      'USD': 83.0,
      'EUR': 90.0,
      'GBP': 105.0,
      'JPY': 0.56,
      'INR': 1.0,
    };

    final fromRate = rates[from] ?? 1.0;
    final toRate = rates[to] ?? 1.0;

    return amount * (toRate / fromRate);
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    final result = <String, double>{};
    for (final entry in requests.entries) {
      final request = entry.value;
      final convertedAmount = await convert(
        amount: request.amount,
        from: request.from,
        to: to,
        date: request.date,
      );
      result[entry.key] = convertedAmount;
    }
    return result;
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    if (from == to) return 1.0;

    // Mock exchange rates to INR
    const rates = {
      'USD': 83.0,
      'EUR': 90.0,
      'GBP': 105.0,
      'JPY': 0.56,
      'INR': 1.0,
    };

    final fromRate = rates[from] ?? 1.0;
    final toRate = rates[to] ?? 1.0;

    return toRate / fromRate;
  }

  void reset() {
    clearCacheCalled = false;
    clearCacheCallCount = 0;
  }

  // Use noSuchMethod to handle all other methods that aren't needed for these tests
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Return appropriate defaults for common return types
    if (invocation.isGetter) {
      // For metrics getter
      return ConversionMetrics();
    }
    // For Future methods, return completed futures with default values
    return super.noSuchMethod(invocation);
  }
}
