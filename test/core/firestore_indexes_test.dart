import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every query that mixes an equality or `whereIn` filter with an order on
/// another field needs a composite index, or it fails with FAILED_PRECONDITION
/// (and the last-known-rate lookup silently returns null).
void main() {
  final indexes =
      (jsonDecode(File('firestore.indexes.json').readAsStringSync())
              as Map<String, dynamic>)['indexes']
          as List<dynamic>;

  /// "collection (scope): field:ORDER, ..." for each declared index.
  final declared = {
    for (final i in indexes)
      '${i['collectionGroup']} (${i['queryScope']}): ${[for (final f in i['fields'] as List) '${f['fieldPath']}:${f['order']}'].join(', ')}',
  };

  test('expected cash flows by investment, ordered by date', () {
    // firestore_expected_cash_flow_repository: where investmentId ==,
    // orderBy expectedDate
    expect(
      declared,
      contains(
        'expectedCashFlows (COLLECTION): investmentId:ASCENDING, expectedDate:ASCENDING',
      ),
    );
  });

  test('expected cash flows by status, ordered by date', () {
    // where status whereIn [...] (+ expectedDate range), orderBy expectedDate
    expect(
      declared,
      contains(
        'expectedCashFlows (COLLECTION): status:ASCENDING, expectedDate:ASCENDING',
      ),
    );
  });

  test('latest exchange rate for a currency pair', () {
    // currency_conversion_service: where from ==, where to ==,
    // orderBy fetchedAt desc, limit 1
    expect(
      declared,
      contains(
        'exchangeRates (COLLECTION): from:ASCENDING, to:ASCENDING, fetchedAt:DESCENDING',
      ),
    );
  });

  test('indexes that were already declared stay declared', () {
    expect(
      declared,
      contains(
        'investments (COLLECTION): status:ASCENDING, createdAt:DESCENDING',
      ),
    );
    expect(
      declared,
      contains(
        'cashflows (COLLECTION): investmentId:ASCENDING, date:DESCENDING',
      ),
    );
    expect(
      declared,
      contains(
        'archivedCashflows (COLLECTION): investmentId:ASCENDING, date:DESCENDING',
      ),
    );
    expect(
      declared,
      contains(
        'goals (COLLECTION): isArchived:ASCENDING, createdAt:DESCENDING',
      ),
    );
  });
}
