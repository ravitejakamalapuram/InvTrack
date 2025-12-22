import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('AIExtractionResult', () {
    ExtractedCashFlow createCashFlow({
      required String id,
      bool isSelected = true,
    }) {
      return ExtractedCashFlow(
        id: id,
        date: DateTime(2024, 1, 15),
        amount: 1000.0,
        type: CashFlowType.invest,
        confidence: 0.95,
        isSelected: isSelected,
      );
    }

    group('constructor', () {
      test('should create empty result by default', () {
        const result = AIExtractionResult();

        expect(result.suggestedInvestmentName, isNull);
        expect(result.cashFlows, isEmpty);
        expect(result.errorMessage, isNull);
        expect(result.rawResponse, isNull);
      });

      test('should create result with cash flows', () {
        final cashFlows = [
          createCashFlow(id: '1'),
          createCashFlow(id: '2'),
        ];

        final result = AIExtractionResult(
          suggestedInvestmentName: 'Test Investment',
          cashFlows: cashFlows,
        );

        expect(result.suggestedInvestmentName, 'Test Investment');
        expect(result.cashFlows.length, 2);
      });

      test('should create result with error', () {
        const result = AIExtractionResult(
          errorMessage: 'Failed to parse document',
        );

        expect(result.hasError, true);
        expect(result.errorMessage, 'Failed to parse document');
      });
    });

    group('isEmpty', () {
      test('should return true when no cash flows', () {
        const result = AIExtractionResult();
        expect(result.isEmpty, true);
      });

      test('should return false when has cash flows', () {
        final result = AIExtractionResult(
          cashFlows: [createCashFlow(id: '1')],
        );
        expect(result.isEmpty, false);
      });
    });

    group('hasError', () {
      test('should return true when errorMessage is set', () {
        const result = AIExtractionResult(errorMessage: 'Error');
        expect(result.hasError, true);
      });

      test('should return false when no errorMessage', () {
        const result = AIExtractionResult();
        expect(result.hasError, false);
      });
    });

    group('selectedCount', () {
      test('should return count of selected cash flows', () {
        final result = AIExtractionResult(
          cashFlows: [
            createCashFlow(id: '1', isSelected: true),
            createCashFlow(id: '2', isSelected: false),
            createCashFlow(id: '3', isSelected: true),
          ],
        );

        expect(result.selectedCount, 2);
      });

      test('should return 0 when no cash flows selected', () {
        final result = AIExtractionResult(
          cashFlows: [
            createCashFlow(id: '1', isSelected: false),
            createCashFlow(id: '2', isSelected: false),
          ],
        );

        expect(result.selectedCount, 0);
      });
    });

    group('selectedCashFlows', () {
      test('should return only selected cash flows', () {
        final result = AIExtractionResult(
          cashFlows: [
            createCashFlow(id: '1', isSelected: true),
            createCashFlow(id: '2', isSelected: false),
            createCashFlow(id: '3', isSelected: true),
          ],
        );

        final selected = result.selectedCashFlows;

        expect(selected.length, 2);
        expect(selected.map((cf) => cf.id).toList(), ['1', '3']);
      });
    });

    group('copyWith', () {
      test('should create copy with updated investment name', () {
        final original = AIExtractionResult(
          suggestedInvestmentName: 'Original',
          cashFlows: [createCashFlow(id: '1')],
        );

        final copy = original.copyWith(suggestedInvestmentName: 'Updated');

        expect(copy.suggestedInvestmentName, 'Updated');
        expect(copy.cashFlows.length, 1);
      });

      test('should create copy with updated cash flows', () {
        final original = AIExtractionResult(
          cashFlows: [createCashFlow(id: '1')],
        );

        final newCashFlows = [
          createCashFlow(id: '1', isSelected: false),
        ];

        final copy = original.copyWith(cashFlows: newCashFlows);

        expect(copy.cashFlows.first.isSelected, false);
      });
    });
  });
}

