import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Tests for maturity date sorting logic.
/// These tests verify the sorting behavior for investments with maturity dates.
void main() {
  group('Maturity Date Sorting Logic', () {
    final now = DateTime(2026, 1, 7);

    final investmentWithEarlyMaturity = InvestmentEntity(
      id: 'early',
      name: 'Early Maturity FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      maturityDate: DateTime(2026, 3, 15), // March 2026
    );

    final investmentWithLateMaturity = InvestmentEntity(
      id: 'late',
      name: 'Late Maturity Bond',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      maturityDate: DateTime(2027, 6, 30), // June 2027
    );

    final investmentWithMidMaturity = InvestmentEntity(
      id: 'mid',
      name: 'Mid Maturity P2P',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      maturityDate: DateTime(2026, 9, 1), // September 2026
    );

    final investmentWithNoMaturity = InvestmentEntity(
      id: 'no-maturity',
      name: 'Stock Investment',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      maturityDate: null, // No maturity date
    );

    final anotherWithNoMaturity = InvestmentEntity(
      id: 'no-maturity-2',
      name: 'Crypto Investment',
      type: InvestmentType.crypto,
      status: InvestmentStatus.open,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      maturityDate: null, // No maturity date
    );

    test('investments with maturity dates should sort by date ascending', () {
      final investments = [
        investmentWithLateMaturity,
        investmentWithEarlyMaturity,
        investmentWithMidMaturity,
      ];

      investments.sort((a, b) => _compareByMaturityDate(a, b));

      expect(investments[0].id, 'early');
      expect(investments[1].id, 'mid');
      expect(investments[2].id, 'late');
    });

    test('investments without maturity date should come last', () {
      final investments = [
        investmentWithNoMaturity,
        investmentWithEarlyMaturity,
        investmentWithLateMaturity,
      ];

      investments.sort((a, b) => _compareByMaturityDate(a, b));

      expect(investments[0].id, 'early');
      expect(investments[1].id, 'late');
      expect(investments[2].id, 'no-maturity');
    });

    test('multiple investments without maturity should maintain relative order', () {
      final investments = [
        investmentWithNoMaturity,
        investmentWithMidMaturity,
        anotherWithNoMaturity,
      ];

      investments.sort((a, b) => _compareByMaturityDate(a, b));

      // Investment with maturity date should come first
      expect(investments[0].id, 'mid');
      // Both no-maturity investments should be at the end
      // Their relative order is preserved (comparison = 0)
      expect(investments[1].maturityDate, isNull);
      expect(investments[2].maturityDate, isNull);
    });

    test('all investments without maturity should compare as equal', () {
      final result = _compareByMaturityDate(
        investmentWithNoMaturity,
        anotherWithNoMaturity,
      );

      expect(result, 0);
    });

    test('investment with maturity should come before one without', () {
      final result = _compareByMaturityDate(
        investmentWithEarlyMaturity,
        investmentWithNoMaturity,
      );

      expect(result, lessThan(0)); // Maturity comes first
    });

    test('investment without maturity should come after one with', () {
      final result = _compareByMaturityDate(
        investmentWithNoMaturity,
        investmentWithEarlyMaturity,
      );

      expect(result, greaterThan(0)); // No maturity goes to end
    });
  });
}

/// Helper function that replicates the maturity date sorting logic
/// from _compareInvestments in investment_list_state_provider.dart
int _compareByMaturityDate(InvestmentEntity a, InvestmentEntity b) {
  final maturityA = a.maturityDate;
  final maturityB = b.maturityDate;

  if (maturityA == null && maturityB == null) {
    return 0;
  } else if (maturityA == null) {
    return 1; // A goes after B
  } else if (maturityB == null) {
    return -1; // A goes before B
  } else {
    return maturityA.compareTo(maturityB);
  }
}
