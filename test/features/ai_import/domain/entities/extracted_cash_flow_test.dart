import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('ExtractedCashFlow', () {
    group('constructor', () {
      test('should create instance with required parameters', () {
        final cashFlow = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.95,
        );

        expect(cashFlow.id, 'test-id');
        expect(cashFlow.date, DateTime(2024, 1, 15));
        expect(cashFlow.amount, 1000.0);
        expect(cashFlow.type, CashFlowType.invest);
        expect(cashFlow.confidence, 0.95);
        expect(cashFlow.notes, isNull);
        expect(cashFlow.isSelected, true);
      });

      test('should create instance with optional parameters', () {
        final cashFlow = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 500.0,
          type: CashFlowType.income,
          confidence: 0.8,
          notes: 'Dividend payment',
          isSelected: false,
        );

        expect(cashFlow.notes, 'Dividend payment');
        expect(cashFlow.isSelected, false);
      });
    });

    group('copyWith', () {
      test('should create copy with updated isSelected', () {
        final original = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.95,
        );

        final copy = original.copyWith(isSelected: false);

        expect(copy.id, original.id);
        expect(copy.date, original.date);
        expect(copy.amount, original.amount);
        expect(copy.isSelected, false);
      });

      test('should create copy with updated amount', () {
        final original = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.95,
        );

        final copy = original.copyWith(amount: 2000.0);

        expect(copy.amount, 2000.0);
        expect(copy.id, original.id);
      });
    });

    group('confidenceLevel', () {
      test('should return High for confidence >= 0.9', () {
        final cashFlow = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.95,
        );

        expect(cashFlow.confidenceLevel, 'High');
      });

      test('should return Medium for confidence >= 0.7 and < 0.9', () {
        final cashFlow = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.75,
        );

        expect(cashFlow.confidenceLevel, 'Medium');
      });

      test('should return Low for confidence < 0.7', () {
        final cashFlow = ExtractedCashFlow(
          id: 'test-id',
          date: DateTime(2024, 1, 15),
          amount: 1000.0,
          type: CashFlowType.invest,
          confidence: 0.5,
        );

        expect(cashFlow.confidenceLevel, 'Low');
      });
    });

    group('fromJson', () {
      test('should parse valid JSON correctly', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000.0,
          'type': 'INVEST',
          'confidence': 0.95,
          'notes': 'Initial investment',
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');

        expect(cashFlow.id, 'test-id');
        expect(cashFlow.date, DateTime(2024, 1, 15));
        expect(cashFlow.amount, 1000.0);
        expect(cashFlow.type, CashFlowType.invest);
        expect(cashFlow.confidence, 0.95);
        expect(cashFlow.notes, 'Initial investment');
      });

      test('should parse RETURN type correctly', () {
        final json = {
          'date': '2024-06-01',
          'amount': 500.0,
          'type': 'RETURN',
          'confidence': 0.9,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.returnFlow);
      });

      test('should parse INCOME type correctly', () {
        final json = {
          'date': '2024-03-15',
          'amount': 50.0,
          'type': 'INCOME',
          'confidence': 0.85,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.income);
      });

      test('should parse FEE type correctly', () {
        final json = {
          'date': '2024-03-15',
          'amount': 25.0,
          'type': 'FEE',
          'confidence': 0.9,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.fee);
      });

      test('should handle null date by using current date', () {
        final json = {
          'date': null,
          'amount': 1000.0,
          'type': 'INVEST',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        final now = DateTime.now();
        expect(cashFlow.date.year, now.year);
        expect(cashFlow.date.month, now.month);
        expect(cashFlow.date.day, now.day);
      });

      test('should handle invalid date format by using current date', () {
        final json = {
          'date': 'invalid-date',
          'amount': 1000.0,
          'type': 'INVEST',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        final now = DateTime.now();
        expect(cashFlow.date.year, now.year);
      });

      test('should handle null amount by defaulting to 0.0', () {
        final json = {
          'date': '2024-01-15',
          'amount': null,
          'type': 'INVEST',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.amount, 0.0);
      });

      test('should handle null type by defaulting to invest', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000.0,
          'type': null,
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.invest);
      });

      test('should handle unknown type by defaulting to invest', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000.0,
          'type': 'UNKNOWN_TYPE',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.invest);
      });

      test('should handle null confidence by defaulting to 0.5', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000.0,
          'type': 'INVEST',
          'confidence': null,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.confidence, 0.5);
      });

      test('should handle integer amount by converting to double', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000,
          'type': 'INVEST',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.amount, 1000.0);
      });

      test('should handle lowercase type', () {
        final json = {
          'date': '2024-01-15',
          'amount': 1000.0,
          'type': 'invest',
          'confidence': 0.95,
        };

        final cashFlow = ExtractedCashFlow.fromJson(json, 'test-id');
        expect(cashFlow.type, CashFlowType.invest);
      });
    });
  });
}

