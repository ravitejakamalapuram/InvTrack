// A64 (#811): the expected cash flow document mapper. A missing optional field
// takes its default; a missing required field is a TypeError today, so these
// tests pin that a bad document fails loudly instead of silently mapping.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

void main() {
  final created = Timestamp.fromDate(DateTime(2026, 1, 5));
  final expectedOn = Timestamp.fromDate(DateTime(2026, 2, 5));

  Map<String, dynamic> minimal() => {
    'investmentId': 'inv-1',
    'expectedDate': expectedOn,
    'expectedAmount': 3500,
    'createdAt': created,
  };

  ExpectedCashFlowEntity map(Map<String, dynamic> data) =>
      FirestoreExpectedCashFlowRepository.expectedCashFlowFromFirestore(
        data,
        'ecf-1',
        baseCurrency: 'INR',
      );

  group('expected cash flow mapper', () {
    test('a minimal document takes the documented defaults', () {
      final e = map(minimal());

      expect(e.id, 'ecf-1');
      expect(e.expectedAmount, 3500.0);
      expect(e.currency, 'INR');
      expect(e.predictionSource, PredictionSource.wma);
      expect(e.status, ExpectedCashFlowStatus.upcoming);
      expect(e.matchedCashFlowId, isNull);
      expect(e.actualAmount, isNull);
      expect(e.actualDate, isNull);
      expect(e.notes, isNull);
      expect(e.platformDelayDays, isNull);
      expect(e.varianceFactor, isNull);
    });

    test('updatedAt falls back to createdAt when it is missing', () {
      final e = map(minimal());

      expect(e.updatedAt, equals(created.toDate()));
    });

    test('a full document maps every field', () {
      final updated = Timestamp.fromDate(DateTime(2026, 2, 6));
      final actual = Timestamp.fromDate(DateTime(2026, 2, 7));
      final e = map({
        ...minimal(),
        'currency': 'USD',
        'predictionSource': 'manual',
        'status': 'received',
        'matchedCashFlowId': 'cf-9',
        'actualAmount': 3400,
        'actualDate': actual,
        'notes': 'late by two days',
        'updatedAt': updated,
        'platformDelayDays': 2,
        'varianceFactor': 0.25,
      });

      expect(e.id, 'ecf-1');
      expect(e.investmentId, 'inv-1');
      expect(e.expectedDate, equals(expectedOn.toDate()));
      expect(e.expectedAmount, 3500.0);
      expect(e.createdAt, equals(created.toDate()));
      expect(e.currency, 'USD');
      expect(e.predictionSource.name, 'manual');
      expect(e.status, ExpectedCashFlowStatus.received);
      expect(e.matchedCashFlowId, 'cf-9');
      expect(e.actualAmount, 3400.0);
      expect(e.actualDate, equals(actual.toDate()));
      expect(e.notes, 'late by two days');
      expect(e.updatedAt, equals(updated.toDate()));
      expect(e.platformDelayDays, 2);
      expect(e.varianceFactor, 0.25);
    });

    test('an unknown status or prediction source falls back, not throws', () {
      final e = map({
        ...minimal(),
        'status': 'archivedByNewerApp',
        'predictionSource': 'neuralNet',
      });

      expect(e.status, ExpectedCashFlowStatus.upcoming);
      expect(e.predictionSource, PredictionSource.wma);
    });

    test('an integer amount is read as a double', () {
      final amount = map({...minimal(), 'expectedAmount': 10}).expectedAmount;

      expect(amount, isA<double>());
      expect(amount, equals(10.0));
    });

    for (final field in [
      'investmentId',
      'expectedDate',
      'expectedAmount',
      'createdAt',
    ]) {
      test('a document without $field fails loudly', () {
        final data = minimal()..remove(field);

        expect(() => map(data), throwsA(isA<TypeError>()));
      });
    }
  });
}
