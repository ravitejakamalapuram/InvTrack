import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';

void main() {
  group('AccessibilityUtils', () {
    group('investmentCardLabel', () {
      test('generates correct label for open investment', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Tech Stocks',
          type: 'Stock',
          currentValue: 50000,
          returnPercent: 12.5,
          currencySymbol: '\$',
          isClosed: false,
        );

        expect(
          label,
          'Open investment: Tech Stocks. Type: Stock. Current value:  50,000 dollars. Returns: positive 12.5 percent',
        );
      });

      test('generates correct label for closed investment', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Old Bond',
          type: 'Bond',
          currentValue: 10000,
          returnPercent: 5.0,
          currencySymbol: '₹',
          isClosed: true,
        );

        expect(
          label,
          'Closed investment: Old Bond. Type: Bond. Current value:  10,000 rupees. Returns: positive 5.0 percent',
        );
      });

      test('generates correct label without returns', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'New Fund',
          type: 'Mutual Fund',
          currentValue: 2000,
          returnPercent: null,
          currencySymbol: '\$',
          isClosed: false,
        );

        expect(
          label,
          'Open investment: New Fund. Type: Mutual Fund. Current value:  2,000 dollars',
        );
      });

      test('generates correct label with invested amount and last activity', () {
        final lastActivity = DateTime(2023, 10, 15);

        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Active Stock',
          type: 'Stock',
          currentValue: 55000,
          returnPercent: 10.0,
          currencySymbol: '\$',
          isClosed: false,
          totalInvested: 50000,
          lastActivityDate: lastActivity,
        );

        expect(
          label,
          contains('Invested:  50,000 dollars'),
        );
        expect(
          label,
          contains('Last activity: October 15, 2023'),
        );
        // Verify order roughly
        expect(
          label,
          'Open investment: Active Stock. Type: Stock. Current value:  55,000 dollars. Invested:  50,000 dollars. Returns: positive 10.0 percent. Last activity: October 15, 2023',
        );
      });

      test('generates correct label for matured investment', () {
        final now = DateTime.now();
        final maturityDate = now.subtract(const Duration(days: 5));

        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Expired Bond',
          type: 'Bond',
          currentValue: 1000,
          returnPercent: 2.0,
          currencySymbol: '\$',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(
          label,
          contains('Matured'),
        );
        expect(label, endsWith('. Matured'));
      });

      test('generates correct label for investment maturing today', () {
        final now = DateTime.now();

        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Maturing Bond',
          type: 'Bond',
          currentValue: 1000,
          returnPercent: 2.0,
          currencySymbol: '\$',
          isClosed: false,
          maturityDate: now,
        );

        expect(
          label,
          contains('Matures today'),
        );
      });

      test('generates correct label for investment maturing soon', () {
        final now = DateTime.now();
        final maturityDate = now.add(const Duration(days: 15));

        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Soon Bond',
          type: 'Bond',
          currentValue: 1000,
          returnPercent: 2.0,
          currencySymbol: '\$',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(
          label,
          contains('Matures in 15 days'),
        );
      });

      test('generates label without maturity info if > 30 days', () {
        final now = DateTime.now();
        final maturityDate = now.add(const Duration(days: 40));

        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Long Bond',
          type: 'Bond',
          currentValue: 1000,
          returnPercent: 2.0,
          currencySymbol: '\$',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(
          label,
          isNot(contains('Matures')),
        );
      });

      test('masks sensitive values when shouldMask is true', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Secret Fund',
          type: 'Stock',
          currentValue: 1000000,
          returnPercent: 25.5,
          currencySymbol: '\$',
          isClosed: false,
          shouldMask: true,
          totalInvested: 800000,
        );

        expect(label, contains('Current value: Hidden amount'));
        expect(label, contains('Invested: Hidden amount'));
        expect(label, contains('Returns: Hidden percentage'));
        expect(label, isNot(contains('1,000,000')));
        expect(label, isNot(contains('800,000')));
        expect(label, isNot(contains('25.5')));
      });

      test('generates correct label with cash flow count', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Active Stock',
          type: 'Stock',
          currentValue: 55000,
          returnPercent: 10.0,
          currencySymbol: '\$',
          isClosed: false,
          cashFlowCount: 5,
        );

        expect(label, contains('5 entries'));
      });

      test('generates correct label with single cash flow entry', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'New Stock',
          type: 'Stock',
          currentValue: 1000,
          returnPercent: 0.0,
          currencySymbol: '\$',
          isClosed: false,
          cashFlowCount: 1,
        );

        expect(label, contains('1 entry'));
      });
    });
  });
}
