import 'package:inv_tracker/core/services/currency_conversion_service.dart';

/// Mock implementation of CurrencyConversionService for testing
class MockCurrencyConversionService implements CurrencyConversionService {
  /// Shared exchange rates (how many INR per 1 unit of currency)
  /// Extracted to prevent drift between convert() and getLastKnownRate()
  static const Map<String, double> _ratesInINR = {
    'USD': 83.0,  // 1 USD = 83 INR
    'EUR': 90.0,  // 1 EUR = 90 INR
    'GBP': 105.0, // 1 GBP = 105 INR
    'JPY': 0.56,  // 1 JPY = 0.56 INR
    'INR': 1.0,   // 1 INR = 1 INR
  };

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

    // Use shared exchange rates constant
    // Fail fast for unsupported currencies to catch test setup errors
    final fromRate = _ratesInINR[from];
    final toRate = _ratesInINR[to];

    if (fromRate == null) {
      throw ArgumentError('Unsupported "from" currency: $from. '
          'Supported: ${_ratesInINR.keys.join(", ")}');
    }
    if (toRate == null) {
      throw ArgumentError('Unsupported "to" currency: $to. '
          'Supported: ${_ratesInINR.keys.join(", ")}');
    }

    // Example: 100 USD to EUR
    // Step 1: 100 USD * 83 = 8300 INR
    // Step 2: 8300 INR / 90 = 92.22 EUR
    final amountInINR = amount * fromRate;
    return amountInINR / toRate;
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

    // Use shared exchange rates constant
    // Fail fast for unsupported currencies
    final fromRate = _ratesInINR[from];
    final toRate = _ratesInINR[to];

    if (fromRate == null) {
      throw ArgumentError('Unsupported "from" currency: $from. '
          'Supported: ${_ratesInINR.keys.join(", ")}');
    }
    if (toRate == null) {
      throw ArgumentError('Unsupported "to" currency: $to. '
          'Supported: ${_ratesInINR.keys.join(", ")}');
    }

    // Return rate: how much 'to' currency per 1 unit of 'from' currency
    // Example: USD to EUR = (1 * 83) / 90 = 0.922
    return fromRate / toRate;
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
