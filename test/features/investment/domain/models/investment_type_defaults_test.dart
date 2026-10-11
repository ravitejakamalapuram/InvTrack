// A40 (#783) PR-2: choosing an investment type chip sets the type and the
// structure that goes with it (payout mode, compounding) and nothing else.
// InvestmentTypeDefaults has no field for a term or an income frequency (a
// frequency schedules income reminders, so only the user sets one), and the
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
      expect(defaults.typicalRate, 7.0);
    });

    test('P2P lending takes the P2P template structure', () {
      final defaults = InvestmentTypeDefaults.forType(
        InvestmentType.p2pLending,
      );

      expect(defaults.payoutMode, InterestPayoutMode.periodic);
      expect(defaults.compounding, CompoundingFrequency.none);
      expect(defaults.typicalRate, 12.0);
    });

    test('gold takes the Gold template structure and its typical rate', () {
      final defaults = InvestmentTypeDefaults.forType(InvestmentType.gold);

      expect(defaults.payoutMode, InterestPayoutMode.periodic);
      expect(defaults.typicalRate, 2.5);
    });

    test('types without a template set nothing', () {
      for (final type in [InvestmentType.stocks, InvestmentType.crypto]) {
        final defaults = InvestmentTypeDefaults.forType(type);

        expect(defaults.payoutMode, isNull, reason: type.name);
        expect(defaults.compounding, isNull, reason: type.name);
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

  // The rule the add form applies when a type chip is chosen: a structural
  // value that is still what the previous chip set follows the new chip; a
  // value the user changed stays. The same comparison tells the analytics
  // which fields the user really used. One rule, here, testable without a
  // widget.
  group('structure after choosing another chip', () {
    final fd = InvestmentTypeDefaults.forType(InvestmentType.fixedDeposit);
    final p2p = InvestmentTypeDefaults.forType(InvestmentType.p2pLending);

    test('fields the user did not pick follow the new chip', () {
      final structure = p2p.applyOver(
        payoutMode: InterestPayoutMode.cumulative,
        payoutModeChosen: false,
        compounding: CompoundingFrequency.quarterly,
        compoundingChosen: false,
      );

      expect(structure.payoutMode, InterestPayoutMode.periodic);
      expect(structure.compounding, CompoundingFrequency.none);
    });

    test('a payout mode the user picked stays, compounding still follows', () {
      final structure = p2p.applyOver(
        payoutMode: InterestPayoutMode.atMaturity,
        payoutModeChosen: true,
        compounding: CompoundingFrequency.quarterly,
        compoundingChosen: false,
      );

      expect(structure.payoutMode, InterestPayoutMode.atMaturity);
      expect(structure.compounding, CompoundingFrequency.none);
    });

    test('a compounding the user picked stays, payout mode still follows', () {
      final structure = p2p.applyOver(
        payoutMode: InterestPayoutMode.cumulative,
        payoutModeChosen: false,
        compounding: CompoundingFrequency.monthly,
        compoundingChosen: true,
      );

      expect(structure.payoutMode, InterestPayoutMode.periodic);
      expect(structure.compounding, CompoundingFrequency.monthly);
    });

    test('from nothing set, empty fields take the new chip', () {
      final structure = fd.applyOver(
        payoutMode: null,
        payoutModeChosen: false,
        compounding: null,
        compoundingChosen: false,
      );

      expect(structure.payoutMode, InterestPayoutMode.cumulative);
      expect(structure.compounding, CompoundingFrequency.quarterly);
    });

    test('a chip without structure clears what the last chip set', () {
      final structure = InvestmentTypeDefaults.none.applyOver(
        payoutMode: InterestPayoutMode.cumulative,
        payoutModeChosen: false,
        compounding: CompoundingFrequency.quarterly,
        compoundingChosen: false,
      );

      expect(structure.payoutMode, isNull);
      expect(structure.compounding, isNull);
    });

    test('a pick that equals another chip\'s default is still a pick', () {
      // Fixed Deposit, the user picks Periodic and Simple Interest (which
      // are what P2P Lending sets), then P2P Lending, then Fixed Deposit
      // again. Comparing with the last chip's values could not tell these
      // picks from what the P2P chip set, and Fixed Deposit would overwrite
      // them with Cumulative and Quarterly.
      final onP2p = p2p.applyOver(
        payoutMode: InterestPayoutMode.periodic,
        payoutModeChosen: true,
        compounding: CompoundingFrequency.none,
        compoundingChosen: true,
      );
      final backOnFd = fd.applyOver(
        payoutMode: onP2p.payoutMode,
        payoutModeChosen: true,
        compounding: onP2p.compounding,
        compoundingChosen: true,
      );

      expect(backOnFd.payoutMode, InterestPayoutMode.periodic);
      expect(backOnFd.compounding, CompoundingFrequency.none);
    });
  });
}
