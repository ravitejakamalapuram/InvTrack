import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('CashFlowType', () {
    group('isOutflow', () {
      test('invest should be outflow', () {
        expect(CashFlowType.invest.isOutflow, true);
      });

      test('fee should be outflow', () {
        expect(CashFlowType.fee.isOutflow, true);
      });

      test('returnFlow should not be outflow', () {
        expect(CashFlowType.returnFlow.isOutflow, false);
      });

      test('income should not be outflow', () {
        expect(CashFlowType.income.isOutflow, false);
      });
    });

    group('isInflow', () {
      test('returnFlow should be inflow', () {
        expect(CashFlowType.returnFlow.isInflow, true);
      });

      test('income should be inflow', () {
        expect(CashFlowType.income.isInflow, true);
      });

      test('invest should not be inflow', () {
        expect(CashFlowType.invest.isInflow, false);
      });

      test('fee should not be inflow', () {
        expect(CashFlowType.fee.isInflow, false);
      });
    });

    group('fromString', () {
      test('should parse INVEST', () {
        expect(CashFlowType.fromString('INVEST'), CashFlowType.invest);
      });

      test('should parse RETURN', () {
        expect(CashFlowType.fromString('RETURN'), CashFlowType.returnFlow);
      });

      test('should parse RETURNFLOW', () {
        expect(CashFlowType.fromString('RETURNFLOW'), CashFlowType.returnFlow);
      });

      test('should parse INCOME', () {
        expect(CashFlowType.fromString('INCOME'), CashFlowType.income);
      });

      test('should parse FEE', () {
        expect(CashFlowType.fromString('FEE'), CashFlowType.fee);
      });

      test('should default to invest for unknown values', () {
        expect(CashFlowType.fromString('UNKNOWN'), CashFlowType.invest);
      });

      test('should be case insensitive', () {
        expect(CashFlowType.fromString('invest'), CashFlowType.invest);
        expect(CashFlowType.fromString('Invest'), CashFlowType.invest);
      });
    });

    group('toDbString', () {
      test('should convert invest to INVEST', () {
        expect(CashFlowType.invest.toDbString(), 'INVEST');
      });

      test('should convert returnFlow to RETURN', () {
        expect(CashFlowType.returnFlow.toDbString(), 'RETURN');
      });

      test('should convert income to INCOME', () {
        expect(CashFlowType.income.toDbString(), 'INCOME');
      });

      test('should convert fee to FEE', () {
        expect(CashFlowType.fee.toDbString(), 'FEE');
      });
    });
  });

  group('CashFlowEntity', () {
    test('signedAmount should be negative for invest', () {
      final cf = CashFlowEntity(
        id: '1',
        investmentId: 'inv1',
        date: DateTime.now(),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime.now(),
      );

      expect(cf.signedAmount, -1000);
    });

    test('signedAmount should be negative for fee', () {
      final cf = CashFlowEntity(
        id: '1',
        investmentId: 'inv1',
        date: DateTime.now(),
        type: CashFlowType.fee,
        amount: 50,
        createdAt: DateTime.now(),
      );

      expect(cf.signedAmount, -50);
    });

    test('signedAmount should be positive for returnFlow', () {
      final cf = CashFlowEntity(
        id: '1',
        investmentId: 'inv1',
        date: DateTime.now(),
        type: CashFlowType.returnFlow,
        amount: 1500,
        createdAt: DateTime.now(),
      );

      expect(cf.signedAmount, 1500);
    });

    test('signedAmount should be positive for income', () {
      final cf = CashFlowEntity(
        id: '1',
        investmentId: 'inv1',
        date: DateTime.now(),
        type: CashFlowType.income,
        amount: 100,
        createdAt: DateTime.now(),
      );

      expect(cf.signedAmount, 100);
    });

    test('copyWith should create copy with updated fields', () {
      final original = CashFlowEntity(
        id: '1',
        investmentId: 'inv1',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 1000,
        notes: 'Original',
        createdAt: DateTime(2023, 1, 1),
      );

      final copy = original.copyWith(amount: 2000, notes: 'Updated');

      expect(copy.id, '1');
      expect(copy.investmentId, 'inv1');
      expect(copy.amount, 2000);
      expect(copy.notes, 'Updated');
      expect(copy.type, CashFlowType.invest);
    });
  });
}
