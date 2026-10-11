// A40 (#783) PR-2: choosing an investment type chip sets the type and the
// structure that goes with it (payout mode, compounding, income frequency)
// and nothing else. InvestmentTypeDefaults has no field for a term, and the
// typical rate is a hint for the empty rate field, never a value to save.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_type_defaults.dart';

void main() {
  group('InvestmentTypeDefaults.forType', () {
    test('fixed deposit takes the Fixed Deposit template structure', () {
      final defaults = InvestmentTypeDefaults.forType(
        InvestmentType.fixedDeposit,
      );

      expect(defaults.payoutMode, InterestPayoutMode.cumulative);
      expect(defaults.compounding, CompoundingFrequency.quarterly);
      expect(defaults.incomeFrequency, IncomeFrequency.quarterly);
      expect(defaults.typicalRate, 7.0);
    });

    test('P2P lending takes the P2P template structure', () {
      final defaults = InvestmentTypeDefaults.forType(
        InvestmentType.p2pLending,
      );

      expect(defaults.payoutMode, InterestPayoutMode.periodic);
      expect(defaults.compounding, CompoundingFrequency.none);
      expect(defaults.incomeFrequency, IncomeFrequency.monthly);
      expect(defaults.typicalRate, 12.0);
    });

    test('gold takes the Gold template structure and its typical rate', () {
      final defaults = InvestmentTypeDefaults.forType(InvestmentType.gold);

      expect(defaults.payoutMode, InterestPayoutMode.periodic);
      expect(defaults.incomeFrequency, IncomeFrequency.semiAnnual);
      expect(defaults.typicalRate, 2.5);
    });

    test('types without a template set nothing', () {
      for (final type in [InvestmentType.stocks, InvestmentType.crypto]) {
        final defaults = InvestmentTypeDefaults.forType(type);

        expect(defaults.payoutMode, isNull, reason: type.name);
        expect(defaults.compounding, isNull, reason: type.name);
        expect(defaults.incomeFrequency, isNull, reason: type.name);
        expect(defaults.typicalRate, isNull, reason: type.name);
        expect(defaults, same(InvestmentTypeDefaults.none), reason: type.name);
      }
    });

    test(
      'every type with a template matches the first template of that type',
      () {
        for (final type in InvestmentType.values) {
          final first = InvestmentTemplates.all
              .where((t) => t.type == type)
              .firstOrNull;
          final defaults = InvestmentTypeDefaults.forType(type);

          expect(
            defaults.payoutMode,
            first?.defaultPayoutMode,
            reason: type.name,
          );
          expect(
            defaults.compounding,
            first?.defaultCompoundingFrequency,
            reason: type.name,
          );
          expect(
            defaults.incomeFrequency,
            first?.defaultIncomeFrequency,
            reason: type.name,
          );
          expect(defaults.typicalRate, first?.typicalRate, reason: type.name);
        }
      },
    );
  });

  group('InvestmentTypeDefaults.forTemplate', () {
    test('Recurring Deposit pays at maturity at 6.5', () {
      final defaults = InvestmentTypeDefaults.forTemplate(
        InvestmentTemplates.recurringDeposit,
      );

      expect(defaults.payoutMode, InterestPayoutMode.atMaturity);
      expect(defaults.compounding, CompoundingFrequency.quarterly);
      expect(defaults.incomeFrequency, isNull);
      expect(defaults.typicalRate, 6.5);
    });
  });

  test('equal structure is equal, so the form can tell what is untouched', () {
    expect(
      InvestmentTypeDefaults.forType(InvestmentType.fixedDeposit),
      InvestmentTypeDefaults.forTemplate(InvestmentTemplates.fixedDeposit),
    );
    expect(
      InvestmentTypeDefaults.forType(InvestmentType.fixedDeposit),
      isNot(InvestmentTypeDefaults.forType(InvestmentType.p2pLending)),
    );
    expect(
      InvestmentTypeDefaults.forType(InvestmentType.fixedDeposit).hashCode,
      InvestmentTypeDefaults.forTemplate(
        InvestmentTemplates.fixedDeposit,
      ).hashCode,
    );
  });
}
