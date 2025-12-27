import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';

void main() {
  group('formatXirr', () {
    test('should format positive XIRR with sign', () {
      expect(formatXirr(0.25), '+25.0%');
      expect(formatXirr(0.123), '+12.3%');
    });

    test('should format negative XIRR without explicit plus', () {
      expect(formatXirr(-0.15), '-15.0%');
      expect(formatXirr(-0.055), '-5.5%');
    });

    test('should round to 1 decimal by default', () {
      expect(formatXirr(0.12345), '+12.3%');
      expect(formatXirr(0.12355), '+12.4%');
    });

    test('should return null for NaN', () {
      expect(formatXirr(double.nan), null);
    });

    test('should return null for infinite values', () {
      expect(formatXirr(double.infinity), null);
      expect(formatXirr(double.negativeInfinity), null);
    });

    test('should return null for extremely large values', () {
      // 5.17e+151 is way over 1000%
      expect(formatXirr(5.17e+149), null);
      expect(formatXirr(100.0), null); // 10000% is over 1000%
    });

    test('should return null for near-zero values', () {
      expect(formatXirr(0.0), null);
      expect(formatXirr(0.0004), null); // 0.04% is below 0.05%
    });

    test('should handle edge case at max threshold', () {
      // 10.0 = 1000%, which is at the max
      expect(formatXirr(10.0), '+1000.0%');
    });

    test('should handle values just below max threshold', () {
      expect(formatXirr(9.99), '+999.0%');
    });

    test('should handle showSign option', () {
      expect(formatXirr(0.25, showSign: false), '25.0%');
      expect(formatXirr(-0.15, showSign: false), '-15.0%');
    });

    test('should respect custom config', () {
      const customConfig = XirrFormatConfig(
        decimalPlaces: 2,
        maxDisplayPercent: 500.0,
      );

      expect(formatXirr(0.12345, config: customConfig), '+12.35%');
      expect(formatXirr(6.0, config: customConfig), null); // 600% > 500%
    });
  });

  group('isValidXirr', () {
    test('should return true for valid values', () {
      expect(isValidXirr(0.25), true);
      expect(isValidXirr(-0.5), true);
    });

    test('should return false for NaN', () {
      expect(isValidXirr(double.nan), false);
    });

    test('should return false for infinite', () {
      expect(isValidXirr(double.infinity), false);
    });

    test('should return false for out of range values', () {
      expect(isValidXirr(100.0), false); // 10000%
      expect(isValidXirr(-2.0), false); // -200%
    });

    test('should return false for near-zero values', () {
      expect(isValidXirr(0.0), false);
    });
  });

  group('formatPercent', () {
    test('should format with default decimals', () {
      expect(formatPercent(25.3), '25.3%');
      expect(formatPercent(-12.5), '-12.5%');
    });

    test('should format with custom decimals', () {
      expect(formatPercent(25.346, decimals: 2), '25.35%');
      expect(formatPercent(25.345, decimals: 0), '25%');
    });

    test('should optionally show sign', () {
      expect(formatPercent(25.3, showSign: true), '+25.3%');
      expect(formatPercent(-12.5, showSign: true), '-12.5%');
    });
  });

  group('formatMultiplier', () {
    test('should format with default decimals', () {
      expect(formatMultiplier(2.5), '2.50x');
      expect(formatMultiplier(1.0), '1.00x');
    });

    test('should format with custom decimals', () {
      expect(formatMultiplier(2.567, decimals: 1), '2.6x');
      expect(formatMultiplier(2.5, decimals: 3), '2.500x');
    });
  });

  group('XirrFormatConfig', () {
    test('default config should have expected values', () {
      expect(XirrFormatConfig.defaultConfig.decimalPlaces, 1);
      expect(XirrFormatConfig.defaultConfig.maxDisplayPercent, 1000.0);
      expect(XirrFormatConfig.defaultConfig.minDisplayPercent, -100.0);
    });
  });
}

