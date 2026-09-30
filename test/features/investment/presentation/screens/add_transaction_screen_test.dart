import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';

void main() {
  group('isReviewPromptSuccessMoment', () {
    test('a new (non-editing) return/exit is a success moment', () {
      expect(
        isReviewPromptSuccessMoment(
          isEditing: false,
          type: CashFlowType.returnFlow,
        ),
        isTrue,
      );
    });

    test('editing an existing return/exit is not a success moment', () {
      expect(
        isReviewPromptSuccessMoment(
          isEditing: true,
          type: CashFlowType.returnFlow,
        ),
        isFalse,
      );
    });

    for (final type in [
      CashFlowType.invest,
      CashFlowType.income,
      CashFlowType.fee,
    ]) {
      test('a new $type is never a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: false, type: type),
          isFalse,
        );
      });
    }
  });
}
