import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('ExtractedInvestment', () {
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
      test('should create investment with required parameters', () {
        final investment = ExtractedInvestment(
          id: 'inv-1',
          suggestedName: 'Test Fund',
        );

        expect(investment.id, 'inv-1');
        expect(investment.suggestedName, 'Test Fund');
        expect(investment.name, 'Test Fund');
        expect(investment.cashFlows, isEmpty);
        expect(investment.isSelected, true);
      });

      test('should use editedName over suggestedName when set', () {
        final investment = ExtractedInvestment(
          id: 'inv-1',
          suggestedName: 'Suggested Name',
          editedName: 'Edited Name',
        );

        expect(investment.name, 'Edited Name');
      });
    });

    group('selectedCashFlowCount', () {
      test('should return count of selected cash flows', () {
        final investment = ExtractedInvestment(
          id: 'inv-1',
          suggestedName: 'Test',
          cashFlows: [
            createCashFlow(id: '1', isSelected: true),
            createCashFlow(id: '2', isSelected: false),
            createCashFlow(id: '3', isSelected: true),
          ],
        );

        expect(investment.selectedCashFlowCount, 2);
      });
    });

    group('fromJson', () {
      test('should parse valid JSON correctly', () {
        int idCounter = 0;
        final json = {
          'investment_name': 'My Fund',
          'cash_flows': [
            {'date': '2024-01-15', 'amount': 1000.0, 'type': 'INVEST', 'confidence': 0.9},
            {'date': '2024-02-15', 'amount': 500.0, 'type': 'INVEST', 'confidence': 0.85},
          ],
        };

        final investment = ExtractedInvestment.fromJson(
          json,
          'inv-1',
          () => 'cf-${idCounter++}',
        );

        expect(investment.suggestedName, 'My Fund');
        expect(investment.cashFlows.length, 2);
        expect(investment.cashFlows[0].id, 'cf-0');
        expect(investment.cashFlows[1].id, 'cf-1');
      });
    });
  });

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

    ExtractedInvestment createInvestment({
      required String id,
      required String name,
      List<ExtractedCashFlow>? cashFlows,
      bool isSelected = true,
    }) {
      return ExtractedInvestment(
        id: id,
        suggestedName: name,
        cashFlows: cashFlows ?? [createCashFlow(id: '$id-cf-1')],
        isSelected: isSelected,
      );
    }

    group('constructor', () {
      test('should create empty result by default', () {
        const result = AIExtractionResult();

        expect(result.investments, isEmpty);
        expect(result.errorMessage, isNull);
        expect(result.rawResponse, isNull);
      });

      test('should create result with investments', () {
        final result = AIExtractionResult(
          investments: [
            createInvestment(id: 'inv-1', name: 'Fund A'),
            createInvestment(id: 'inv-2', name: 'Fund B'),
          ],
        );

        expect(result.investments.length, 2);
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
      test('should return true when no investments', () {
        const result = AIExtractionResult();
        expect(result.isEmpty, true);
      });

      test('should return true when investments have no cash flows', () {
        final result = AIExtractionResult(
          investments: [
            ExtractedInvestment(id: 'inv-1', suggestedName: 'Empty Fund'),
          ],
        );
        expect(result.isEmpty, true);
      });

      test('should return false when has investments with cash flows', () {
        final result = AIExtractionResult(
          investments: [createInvestment(id: 'inv-1', name: 'Fund A')],
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
      test('should return total count of selected cash flows across investments', () {
        final result = AIExtractionResult(
          investments: [
            createInvestment(
              id: 'inv-1',
              name: 'Fund A',
              cashFlows: [
                createCashFlow(id: '1', isSelected: true),
                createCashFlow(id: '2', isSelected: false),
              ],
            ),
            createInvestment(
              id: 'inv-2',
              name: 'Fund B',
              cashFlows: [
                createCashFlow(id: '3', isSelected: true),
                createCashFlow(id: '4', isSelected: true),
              ],
            ),
          ],
        );

        expect(result.selectedCount, 3);
      });

      test('should not count cash flows from deselected investments', () {
        final result = AIExtractionResult(
          investments: [
            createInvestment(
              id: 'inv-1',
              name: 'Fund A',
              isSelected: false,
              cashFlows: [createCashFlow(id: '1', isSelected: true)],
            ),
            createInvestment(
              id: 'inv-2',
              name: 'Fund B',
              isSelected: true,
              cashFlows: [createCashFlow(id: '2', isSelected: true)],
            ),
          ],
        );

        expect(result.selectedCount, 1);
      });
    });

    group('selectedInvestmentCount', () {
      test('should return count of selected investments', () {
        final result = AIExtractionResult(
          investments: [
            createInvestment(id: 'inv-1', name: 'Fund A', isSelected: true),
            createInvestment(id: 'inv-2', name: 'Fund B', isSelected: false),
            createInvestment(id: 'inv-3', name: 'Fund C', isSelected: true),
          ],
        );

        expect(result.selectedInvestmentCount, 2);
      });
    });

    group('copyWith', () {
      test('should create copy with updated investments', () {
        final original = AIExtractionResult(
          investments: [createInvestment(id: 'inv-1', name: 'Original')],
        );

        final copy = original.copyWith(
          investments: [createInvestment(id: 'inv-2', name: 'Updated')],
        );

        expect(copy.investments.first.suggestedName, 'Updated');
      });

      test('should preserve other fields when updating investments', () {
        final original = AIExtractionResult(
          investments: [createInvestment(id: 'inv-1', name: 'Test')],
          rawResponse: '{"test": true}',
        );

        final copy = original.copyWith(errorMessage: 'New error');

        expect(copy.investments.length, 1);
        expect(copy.rawResponse, '{"test": true}');
        expect(copy.errorMessage, 'New error');
      });
    });
  });
}

