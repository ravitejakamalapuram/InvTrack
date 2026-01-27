import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';

void main() {
  group('InvestmentTemplate', () {
    test('should create template with all required fields', () {
      const template = InvestmentTemplate(
        id: 'test',
        name: 'Test Template',
        description: 'A test template',
        type: InvestmentType.fixedDeposit,
        icon: Icons.account_balance,
        color: Colors.green,
        emoji: '🏦',
      );

      expect(template.id, 'test');
      expect(template.name, 'Test Template');
      expect(template.description, 'A test template');
      expect(template.type, InvestmentType.fixedDeposit);
      expect(template.icon, Icons.account_balance);
      expect(template.color, Colors.green);
      expect(template.emoji, '🏦');
    });

    test('should have nullable optional fields', () {
      const template = InvestmentTemplate(
        id: 'test',
        name: 'Test',
        description: 'Test',
        type: InvestmentType.stocks,
        icon: Icons.trending_up,
        color: Colors.blue,
        emoji: '📈',
      );

      expect(template.suggestedNamePrefix, isNull);
      expect(template.typicalRate, isNull);
      expect(template.defaultTenureMonths, isNull);
      expect(template.defaultIncomeFrequency, isNull);
      expect(template.defaultPayoutMode, isNull);
      expect(template.defaultRiskLevel, isNull);
      expect(template.defaultCompoundingFrequency, isNull);
    });
  });

  group('InvestmentTemplates', () {
    test('should have 7 predefined templates', () {
      expect(InvestmentTemplates.all.length, 7);
    });

    test('all templates should have unique IDs', () {
      final ids = InvestmentTemplates.all.map((t) => t.id).toSet();
      expect(ids.length, InvestmentTemplates.all.length);
    });

    test('byId should return correct template', () {
      final fd = InvestmentTemplates.byId('fd');
      expect(fd, isNotNull);
      expect(fd!.name, 'Fixed Deposit');
      expect(fd.type, InvestmentType.fixedDeposit);

      final p2p = InvestmentTemplates.byId('p2p');
      expect(p2p, isNotNull);
      expect(p2p!.name, 'P2P Lending');
      expect(p2p.type, InvestmentType.p2pLending);
    });

    test('byId should return null for unknown ID', () {
      final unknown = InvestmentTemplates.byId('unknown');
      expect(unknown, isNull);
    });

    group('fixedDeposit template', () {
      test('should have correct defaults', () {
        const fd = InvestmentTemplates.fixedDeposit;
        expect(fd.id, 'fd');
        expect(fd.type, InvestmentType.fixedDeposit);
        expect(fd.typicalRate, 7.0);
        expect(fd.defaultTenureMonths, 12);
        expect(fd.defaultIncomeFrequency, IncomeFrequency.quarterly);
        expect(fd.defaultPayoutMode, InterestPayoutMode.cumulative);
        expect(fd.defaultRiskLevel, RiskLevel.low);
        expect(fd.defaultCompoundingFrequency, CompoundingFrequency.quarterly);
      });
    });

    group('p2pLending template', () {
      test('should have correct defaults', () {
        const p2p = InvestmentTemplates.p2pLending;
        expect(p2p.id, 'p2p');
        expect(p2p.type, InvestmentType.p2pLending);
        expect(p2p.typicalRate, 12.0);
        expect(p2p.defaultRiskLevel, RiskLevel.medium);
        expect(p2p.defaultCompoundingFrequency, CompoundingFrequency.none);
      });
    });

    group('mutualFundSIP template', () {
      test('should have correct defaults', () {
        const sip = InvestmentTemplates.mutualFundSIP;
        expect(sip.id, 'sip');
        expect(sip.type, InvestmentType.mutualFunds);
        expect(sip.typicalRate, 12.0);
        expect(sip.defaultTenureMonths, isNull); // SIPs are open-ended
        expect(sip.defaultRiskLevel, RiskLevel.medium);
      });
    });

    group('gold template', () {
      test('should have correct defaults', () {
        const gold = InvestmentTemplates.gold;
        expect(gold.id, 'gold');
        expect(gold.type, InvestmentType.gold);
        expect(gold.typicalRate, 2.5);
        expect(gold.defaultTenureMonths, 96); // 8 years for SGB
        expect(gold.defaultRiskLevel, RiskLevel.low);
      });
    });

    group('bonds template', () {
      test('should have correct defaults', () {
        const bonds = InvestmentTemplates.bonds;
        expect(bonds.id, 'bonds');
        expect(bonds.type, InvestmentType.bonds);
        expect(bonds.typicalRate, 9.0);
        expect(bonds.defaultTenureMonths, 36);
        expect(bonds.defaultRiskLevel, RiskLevel.medium);
      });
    });

    group('recurringDeposit template', () {
      test('should have correct defaults', () {
        const rd = InvestmentTemplates.recurringDeposit;
        expect(rd.id, 'rd');
        expect(rd.type, InvestmentType.fixedDeposit); // RD uses FD type
        expect(rd.typicalRate, 6.5);
        expect(rd.defaultPayoutMode, InterestPayoutMode.atMaturity);
      });
    });

    group('rentalProperty template', () {
      test('should have correct defaults', () {
        const rental = InvestmentTemplates.rentalProperty;
        expect(rental.id, 'rental');
        expect(rental.type, InvestmentType.realEstate);
        expect(rental.typicalRate, 3.0);
        expect(rental.defaultIncomeFrequency, IncomeFrequency.monthly);
      });
    });
  });
}

