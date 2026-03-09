import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_form_config.dart';

void main() {
  group('InvestmentFormConfig', () {
    test('default constructor should have all fields false', () {
      const config = InvestmentFormConfig();
      expect(config.showStartDate, isFalse);
      expect(config.showExpectedRate, isFalse);
      expect(config.showTenure, isFalse);
      expect(config.showPlatform, isFalse);
      expect(config.showPayoutMode, isFalse);
      expect(config.showAutoRenewal, isFalse);
      expect(config.showRiskLevel, isFalse);
      expect(config.showCompoundingFrequency, isFalse);
    });

    group('forType', () {
      test('fixedDeposit should show all relevant fields', () {
        final config = InvestmentFormConfig.forType(
          InvestmentType.fixedDeposit,
        );
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showPayoutMode, isTrue);
        expect(config.showAutoRenewal, isTrue);
        expect(config.showCompoundingFrequency, isTrue);
        expect(config.showRiskLevel, isFalse); // FD is low risk by default
      });

      test('p2pLending should show rate, tenure, platform, and risk', () {
        final config = InvestmentFormConfig.forType(InvestmentType.p2pLending);
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showRiskLevel, isTrue);
        expect(config.showPayoutMode, isFalse);
        expect(config.showAutoRenewal, isFalse);
        expect(config.showCompoundingFrequency, isFalse);
      });

      test('bonds should show payout mode and risk', () {
        final config = InvestmentFormConfig.forType(InvestmentType.bonds);
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showPayoutMode, isTrue);
        expect(config.showRiskLevel, isTrue);
        expect(config.showAutoRenewal, isFalse);
        expect(config.showCompoundingFrequency, isFalse);
      });

      test('mutualFunds should show minimal fields', () {
        final config = InvestmentFormConfig.forType(InvestmentType.mutualFunds);
        expect(config.showStartDate, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showRiskLevel, isTrue);
        expect(config.showExpectedRate, isFalse); // MF returns are variable
        expect(config.showTenure, isFalse); // Open-ended
        expect(config.showPayoutMode, isFalse);
        expect(config.showAutoRenewal, isFalse);
        expect(config.showCompoundingFrequency, isFalse);
      });

      test('stocks should show minimal fields', () {
        final config = InvestmentFormConfig.forType(InvestmentType.stocks);
        expect(config.showStartDate, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showRiskLevel, isTrue);
        expect(config.showExpectedRate, isFalse);
        expect(config.showTenure, isFalse);
      });

      test('gold should show rate and tenure', () {
        final config = InvestmentFormConfig.forType(InvestmentType.gold);
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showRiskLevel, isFalse);
      });

      test('realEstate should show expected rate', () {
        final config = InvestmentFormConfig.forType(InvestmentType.realEstate);
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showTenure, isFalse);
        expect(config.showRiskLevel, isFalse);
      });

      test('crypto should show platform and risk', () {
        final config = InvestmentFormConfig.forType(InvestmentType.crypto);
        expect(config.showStartDate, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showRiskLevel, isTrue);
        expect(config.showExpectedRate, isFalse);
        expect(config.showTenure, isFalse);
      });

      test('chitFunds should show tenure', () {
        final config = InvestmentFormConfig.forType(InvestmentType.chitFunds);
        expect(config.showStartDate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showExpectedRate, isFalse);
      });

      test('financing should show rate and tenure', () {
        final config = InvestmentFormConfig.forType(InvestmentType.financing);
        expect(config.showStartDate, isTrue);
        expect(config.showExpectedRate, isTrue);
        expect(config.showTenure, isTrue);
        expect(config.showPlatform, isTrue);
      });

      test('other should show minimal fields', () {
        final config = InvestmentFormConfig.forType(InvestmentType.other);
        expect(config.showStartDate, isTrue);
        expect(config.showPlatform, isTrue);
        expect(config.showExpectedRate, isFalse);
        expect(config.showTenure, isFalse);
        expect(config.showRiskLevel, isFalse);
      });

      test('all investment types should have a config', () {
        // Ensure no exception is thrown for any type
        for (final type in InvestmentType.values) {
          expect(
            () => InvestmentFormConfig.forType(type),
            returnsNormally,
            reason: 'Config should exist for $type',
          );
        }
      });

      test('all configs should show at least startDate', () {
        for (final type in InvestmentType.values) {
          final config = InvestmentFormConfig.forType(type);
          expect(
            config.showStartDate,
            isTrue,
            reason: 'All types should show start date: $type',
          );
        }
      });
    });
  });
}
