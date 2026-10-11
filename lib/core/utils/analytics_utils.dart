/// Privacy-safe analytics utility functions.
///
/// Provides privacy-preserving data transformation functions for analytics
/// tracking, ensuring compliance with InvTrack Enterprise Rules (Rule 9 and
/// Rule 17.4).
///
/// Never log exact amounts, PII, or sensitive financial data. Always use
/// privacy-safe ranges for monetary values.
library;

import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Get privacy-safe amount range bucket for analytics.
///
/// Converts exact monetary amounts into range buckets to prevent logging
/// sensitive financial data in analytics.
///
/// **Privacy Compliance:**
/// - ✅ Complies with InvTrack Enterprise Rule 9 (Analytics Privacy)
/// - ✅ Complies with InvTrack Enterprise Rule 17.4 (No PII/financial data)
/// - ✅ Never exposes exact investment amounts
/// - ✅ Provides sufficient granularity for analytics insights
///
/// **Range Buckets:**
/// - `under_1k`: 0 to 999
/// - `1k_10k`: 1,000 to 9,999
/// - `10k_50k`: 10,000 to 49,999
/// - `50k_1L`: 50,000 to 99,999 (1 Lakh)
/// - `1L_5L`: 1,00,000 to 4,99,999 (1 to 5 Lakhs)
/// - `5L_10L`: 5,00,000 to 9,99,999 (5 to 10 Lakhs)
/// - `over_10L`: 10,00,000+ (over 10 Lakhs)
///
/// **Example Usage:**
/// ```dart
/// // ✅ GOOD: Privacy-safe analytics
/// analytics.logEvent(
///   name: 'investment_created',
///   parameters: {
///     'amount_range': getAmountRange(investment.amount),
///   },
/// );
///
/// // ❌ BAD: Exposes exact amount
/// analytics.logEvent(
///   name: 'investment_created',
///   parameters: {
///     'amount': investment.amount, // Privacy violation!
///   },
/// );
/// ```
///
/// @param amount The exact monetary amount to bucket
/// @return Privacy-safe range bucket string
String getAmountRange(double amount) {
  if (amount < 1000) return 'under_1k';
  if (amount < 10000) return '1k_10k';
  if (amount < 50000) return '10k_50k';
  if (amount < 100000) return '50k_1L';
  if (amount < 500000) return '1L_5L';
  if (amount < 1000000) return '5L_10L';
  return 'over_10L';
}

/// `amount_range` value for an amount that could not be put in the user's base
/// currency (offline with no cached rate, an unknown currency, signed out).
const unknownAmountRange = 'unknown';

/// Privacy-safe bucket of [cashFlow]'s amount in [baseCurrency].
///
/// Buckets compare amounts in one currency (money rule 2), so a flow in
/// another currency is converted with [converter] first, as the app's totals
/// are. When that is not possible the result is [unknownAmountRange]: never
/// the native amount under the base currency's buckets. Never throws.
Future<String> getBaseCurrencyAmountRange({
  required CashFlowEntity cashFlow,
  required String baseCurrency,
  required BatchCurrencyConverter? converter,
}) async {
  if (cashFlow.currency == baseCurrency) {
    return getAmountRange(cashFlow.amount);
  }
  if (converter == null) return unknownAmountRange;
  try {
    final converted = await converter.batchConvert(
      cashFlows: [cashFlow],
      baseCurrency: baseCurrency,
    );
    // Without a rate the converter hands the flow back unconverted. Only a
    // flow now in the base currency may be bucketed, and a bad rate (zero,
    // negative, NaN, infinite) must not fall into a real bucket.
    final flow = converted.singleOrNull;
    if (flow == null ||
        flow.currency != baseCurrency ||
        !flow.amount.isFinite ||
        flow.amount <= 0) {
      return unknownAmountRange;
    }
    return getAmountRange(flow.amount);
  } catch (_) {
    return unknownAmountRange;
  }
}
