import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockInvestmentRepository extends Mock implements InvestmentRepository {}

void main() {
  late MockInvestmentRepository mockInvestmentRepository;

  setUp(() {
    mockInvestmentRepository = MockInvestmentRepository();
  });

  testWidgets('InvestmentDetailScreen shows transactions and allows adding new one', (tester) async {
    final investment = InvestmentEntity(
      id: '1',
      portfolioId: 'p1',
      name: 'Apple',
      symbol: 'AAPL',
      type: 'Stock',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final transaction = TransactionEntity(
      id: 't1',
      investmentId: '1',
      date: DateTime.now(),
      type: 'BUY',
      quantity: 10,
      pricePerUnit: 150,
      fees: 5,
      totalAmount: 1505,
      createdAt: DateTime.now(),
    );

    when(() => mockInvestmentRepository.watchTransactionsByInvestment('1'))
        .thenAnswer((_) => Stream.value([transaction]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(mockInvestmentRepository),
        ],
        child: MaterialApp(
          home: InvestmentDetailScreen(investment: investment),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify transaction is shown
    expect(find.text('BUY 10.0 units'), findsOneWidget);
    expect(find.text('\$1505.00'), findsOneWidget);

    // Verify Add Transaction button
    expect(find.text('Add Transaction'), findsOneWidget);

    // Tap Add Transaction
    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    // Verify Add Transaction Screen is shown
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Save Transaction'), findsOneWidget);
  });
}
