import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';

void main() {
  group('AccessibilityUtils', () {
    // Screen readers must hear amounts the way they are shown: lakh and crore
    // for INR, no stray space before positive amounts, and the same rounding
    // as the compact amount on screen (A18, UX-08).
    group('formatCurrencyForScreenReader', () {
      String inr(double v) => AccessibilityUtils.formatCurrencyForScreenReader(
        v,
        '₹',
        locale: 'en_IN',
      );

      test('reads INR in lakh and crore', () {
        expect(inr(10505000), '1.05 crore rupees');
        expect(inr(150000), '1.5 lakh rupees');
        expect(inr(9994999), '99.95 lakh rupees');
        expect(inr(9999999), '1 crore rupees');
        expect(inr(1e10), '1,000 crore rupees');
      });

      test('reads INR below one lakh with Indian grouping', () {
        expect(inr(99999), '99,999 rupees');
        expect(inr(1234.5), '1,235 rupees');
        expect(inr(512.75), '512.75 rupees');
      });

      test('says negative once, and no stray space when positive', () {
        expect(inr(-100000), 'negative 1 lakh rupees');
        expect(inr(-99999), 'negative 99,999 rupees');
        expect(inr(-0.001), '0 rupees');
      });

      test('reads other currencies with English grouping', () {
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(
            50000,
            '\$',
            locale: 'en_US',
          ),
          '50,000 dollars',
        );
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(
            -1234567.5,
            '€',
            locale: 'de_DE',
          ),
          'negative 1,234,567.5 euros',
        );
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(
            -0.0001,
            '\$',
            locale: 'en_US',
          ),
          '0 dollars',
        );
      });
    });

    group('transactionLabel', () {
      test('reads the amount in the currency locale', () {
        expect(
          AccessibilityUtils.transactionLabel(
            type: 'Income',
            amount: 250000,
            date: DateTime(2026, 4, 1),
            currencySymbol: '₹',
            currencyLocale: 'en_IN',
          ),
          'Income of 2.5 lakh rupees on April 1, 2026',
        );
      });
    });

    group('investmentCardLabel', () {
      test('generates correct label for open investment', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Tech Stocks',
          type: 'Stock',
          currentValue: 50000,
          returnPercent: 12.5,
          currencySymbol: '\$',
          currencyLocale: 'en_US',
          isClosed: false,
        );

        expect(
          label,
          'Open investment: Tech Stocks. Type: Stock. Current value: 50,000 dollars. Returns: positive 12.5 percent',
        );
      });

      test('generates correct label for closed investment', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Old Bond',
          type: 'Bond',
          currentValue: 10000,
          returnPercent: 5.0,
          currencySymbol: '₹',
          currencyLocale: 'en_IN',
          isClosed: true,
        );

        expect(
          label,
          'Closed investment: Old Bond. Type: Bond. Current value: 10,000 rupees. Returns: positive 5.0 percent',
        );
      });

      test('generates correct label without returns', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'New Fund',
          type: 'Mutual Fund',
          currentValue: 2000,
          returnPercent: null,
          currencySymbol: '\$',
          currencyLocale: 'en_US',
          isClosed: false,
        );

        expect(
          label,
          'Open investment: New Fund. Type: Mutual Fund. Current value: 2,000 dollars',
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
          currencyLocale: 'en_US',
          isClosed: false,
          totalInvested: 50000,
          lastActivityDate: lastActivity,
        );

        expect(label, contains('Invested: 50,000 dollars'));
        expect(label, contains('Last activity: October 15, 2023'));
        // Verify order roughly
        expect(
          label,
          'Open investment: Active Stock. Type: Stock. Current value: 55,000 dollars. Invested: 50,000 dollars. Returns: positive 10.0 percent. Last activity: October 15, 2023',
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
          currencyLocale: 'en_US',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(label, contains('Matured'));
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
          currencyLocale: 'en_US',
          isClosed: false,
          maturityDate: now,
        );

        expect(label, contains('Matures today'));
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
          currencyLocale: 'en_US',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(label, contains('Matures in 15 days'));
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
          currencyLocale: 'en_US',
          isClosed: false,
          maturityDate: maturityDate,
        );

        expect(label, isNot(contains('Matures')));
      });

      test('reads an INR card value in lakh', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'HDFC FD',
          type: 'Fixed Deposit',
          currentValue: 512000,
          returnPercent: 7.0,
          currencySymbol: '₹',
          currencyLocale: 'en_IN',
          isClosed: false,
          totalInvested: 500000,
        );

        expect(
          label,
          'Open investment: HDFC FD. Type: Fixed Deposit. '
          'Current value: 5.12 lakh rupees. Invested: 5 lakh rupees. '
          'Returns: positive 7.0 percent',
        );
      });

      test('masks sensitive values when shouldMask is true', () {
        final label = AccessibilityUtils.investmentCardLabel(
          name: 'Secret Fund',
          type: 'Stock',
          currentValue: 1000000,
          returnPercent: 25.5,
          currencySymbol: '\$',
          currencyLocale: 'en_US',
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
    });
  });
}
