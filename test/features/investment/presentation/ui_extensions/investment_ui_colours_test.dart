// The colours of an investment type: the fill (tile, chart and selected chip),
// the text and icon colour on its pale tint, and the tint. The same pair is
// painted by the investment card, the filter chip, the merge dialog and the
// goal picker, and test/core/theme/contrast_pairs.dart reads it from here.
//
// Colour is never the only carrier of the type: every type has its own name
// and icon, so the four types that share a fill (crypto and private equity,
// mutual funds and P2P lending) stay apart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

import '../../../../helpers/contrast.dart';

// The fill of each type. Ten keep the colour they always had; the purple and
// the blue that carried a white label at 4.23 and 3.68 are deepened.
const _fills = <InvestmentType, int>{
  InvestmentType.p2pLending: 0xFF2A70E3,
  InvestmentType.fixedDeposit: 0xFF10B981,
  InvestmentType.bonds: 0xFFF59E0B,
  InvestmentType.realEstate: 0xFFEC4899,
  InvestmentType.privateEquity: 0xFF8555EF,
  InvestmentType.angelInvesting: 0xFF06B6D4,
  InvestmentType.chitFunds: 0xFFF97316,
  InvestmentType.gold: 0xFFFFD700,
  InvestmentType.crypto: 0xFF8555EF,
  InvestmentType.mutualFunds: 0xFF2A70E3,
  InvestmentType.stocks: 0xFF10B981,
  InvestmentType.invoiceDiscounting: 0xFF0EA5E9,
  InvestmentType.financing: 0xFF14B8A6,
  InvestmentType.other: 0xFF6B7280,
};

// The type name on its tint in light, and in dark where the fill itself does
// not reach 4.5:1 on the dark tint.
const _lightText = <InvestmentType, int>{
  InvestmentType.angelInvesting: 0xFF00798E,
  InvestmentType.bonds: 0xFF9D6300,
  InvestmentType.chitFunds: 0xFFB64F00,
  InvestmentType.crypto: 0xFF7D4CE5,
  InvestmentType.financing: 0xFF007D70,
  InvestmentType.fixedDeposit: 0xFF007E56,
  InvestmentType.gold: 0xFF867000,
  InvestmentType.invoiceDiscounting: 0xFF0075A8,
  InvestmentType.mutualFunds: 0xFF2168DA,
  InvestmentType.other: 0xFF666D7A,
  InvestmentType.p2pLending: 0xFF2168DA,
  InvestmentType.privateEquity: 0xFF7D4CE5,
  InvestmentType.realEstate: 0xFFCA227D,
  InvestmentType.stocks: 0xFF007E56,
};
const _darkText = <InvestmentType, int>{
  InvestmentType.crypto: 0xFF976EFF,
  InvestmentType.mutualFunds: 0xFF4087FB,
  InvestmentType.other: 0xFF818997,
  InvestmentType.p2pLending: 0xFF4087FB,
  InvestmentType.privateEquity: 0xFF976EFF,
};

double _hue(Color c) => HSLColor.fromColor(c).hue;

double _hueGap(Color a, Color b) {
  final d = (_hue(a) - _hue(b)).abs();
  return d > 180 ? 360 - d : d;
}

void main() {
  test('the fills are the ones in the table', () {
    for (final type in InvestmentType.values) {
      expect(type.color, Color(_fills[type]!), reason: type.name);
    }
    expect(_fills.length, InvestmentType.values.length);
  });

  test('a label or icon on the fill reaches 4.5:1 for every type', () {
    for (final type in InvestmentType.values) {
      final ratio = contrastRatio(AppColors.onFill(type.color), type.color);
      expect(
        ratio,
        greaterThanOrEqualTo(kMinText),
        reason: 'inv-${type.name}-label@fill is ${ratio.toStringAsFixed(2)}',
      );
    }
  });

  test('the text colour of each type, in light and in dark', () {
    for (final type in InvestmentType.values) {
      expect(
        type.textColor(Brightness.light),
        Color(_lightText[type]!),
        reason: '${type.name} light',
      );
      expect(
        type.textColor(Brightness.dark),
        Color(_darkText[type] ?? _fills[type]!),
        reason: '${type.name} dark',
      );
    }
  });

  test('the tint is the fill at 10% over the card of the theme', () {
    for (final type in InvestmentType.values) {
      expect(
        type.tintColor(Brightness.light),
        Color.alphaBlend(
          type.color.withValues(alpha: 0.1),
          AppColors.cardLight,
        ),
        reason: '${type.name} light',
      );
      expect(
        type.tintColor(Brightness.dark),
        Color.alphaBlend(type.color.withValues(alpha: 0.1), AppColors.cardDark),
        reason: '${type.name} dark',
      );
      expect(type.tintColor(Brightness.light).a, 1);
      expect(type.tintColor(Brightness.dark).a, 1);
    }
  });

  test('the type name reaches 4.5:1 on its tint in both themes', () {
    for (final type in InvestmentType.values) {
      for (final b in Brightness.values) {
        final ratio = contrastRatio(type.textColor(b), type.tintColor(b));
        expect(
          ratio,
          greaterThanOrEqualTo(kMinText),
          reason:
              'inv-${type.name}-${b.name}@tint10 is ${ratio.toStringAsFixed(2)}',
        );
      }
    }
  });

  test('the thin margins stay above 4.5:1 with the tint that follows the '
      'deeper fill', () {
    // The tint follows the deepened purple and blue, so these are the margins
    // that were audited as 4.60 and 4.63 on the old tint.
    double r(InvestmentType t, Brightness b) =>
        contrastRatio(t.textColor(b), t.tintColor(b));
    expect(r(InvestmentType.crypto, Brightness.light), closeTo(4.57, 0.02));
    expect(
      r(InvestmentType.mutualFunds, Brightness.light),
      closeTo(4.56, 0.02),
    );
    expect(r(InvestmentType.crypto, Brightness.dark), closeTo(4.67, 0.02));
    expect(r(InvestmentType.mutualFunds, Brightness.dark), closeTo(4.74, 0.02));
  });

  test('a type text keeps the hue of its fill', () {
    for (final type in InvestmentType.values) {
      for (final b in Brightness.values) {
        expect(
          _hueGap(type.textColor(b), type.color),
          lessThan(8),
          reason: '${type.name} ${b.name}',
        );
      }
    }
  });

  test('every type has its own name and icon, so colour is not the only '
      'carrier', () {
    final names = {for (final t in InvestmentType.values) t.displayName};
    final icons = {for (final t in InvestmentType.values) t.icon};
    expect(names.length, InvestmentType.values.length);
    expect(icons.length, InvestmentType.values.length);
  });

  test('goal and document types, which reach the same selector chip, have '
      'a fill a label reaches 4.5:1 on', () {
    for (final color in [
      for (final t in GoalType.values) t.color,
      for (final t in DocumentType.values) t.color,
    ]) {
      expect(
        contrastRatio(AppColors.onFill(color), color),
        greaterThanOrEqualTo(kMinText),
        reason: '#${color.toARGB32().toRadixString(16)}',
      );
    }
  });

  group('a document type, which has its own name and icon, reads on its tint '
      'like an investment type', () {
    const lightText = <DocumentType, int>{
      DocumentType.receipt: 0xFF007E56,
      DocumentType.contract: 0xFF2168DA,
      DocumentType.statement: 0xFF9D6300,
      DocumentType.certificate: 0xFF7D4CE5,
      DocumentType.image: 0xFFCA227D,
      DocumentType.other: 0xFF666D7A,
    };
    // In dark the fill itself reads, except for three types.
    const darkText = <DocumentType, int>{
      DocumentType.contract: 0xFF4087FB,
      DocumentType.certificate: 0xFF976EFF,
      DocumentType.other: 0xFF818997,
    };

    test('the text colour of each type, in light and in dark', () {
      for (final type in DocumentType.values) {
        expect(
          type.textColor(Brightness.light),
          Color(lightText[type]!),
          reason: '${type.name} light',
        );
        expect(
          type.textColor(Brightness.dark),
          Color(darkText[type] ?? type.color.toARGB32()),
          reason: '${type.name} dark',
        );
      }
    });

    test('the tint is the fill at 10% over the card, opaque', () {
      for (final type in DocumentType.values) {
        expect(
          type.tintColor(Brightness.light),
          Color.alphaBlend(
            type.color.withValues(alpha: 0.1),
            AppColors.cardLight,
          ),
          reason: '${type.name} light',
        );
        expect(
          type.tintColor(Brightness.dark),
          Color.alphaBlend(
            type.color.withValues(alpha: 0.1),
            AppColors.cardDark,
          ),
          reason: '${type.name} dark',
        );
        expect(type.tintColor(Brightness.light).a, 1);
        expect(type.tintColor(Brightness.dark).a, 1);
      }
    });

    test('the type name reaches 4.5:1 on its tint in both themes', () {
      for (final type in DocumentType.values) {
        for (final b in Brightness.values) {
          final ratio = contrastRatio(type.textColor(b), type.tintColor(b));
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason: 'doc-${type.name}-${b.name}@tint10 is $ratio',
          );
        }
      }
    });

    test('a type text keeps the hue of its fill', () {
      for (final type in DocumentType.values) {
        for (final b in Brightness.values) {
          expect(
            _hueGap(type.textColor(b), type.color),
            lessThan(8),
            reason: '${type.name} ${b.name}',
          );
        }
      }
    });

    test('every document type has its own name and icon', () {
      expect(
        {for (final t in DocumentType.values) t.displayName}.length,
        DocumentType.values.length,
      );
      expect(
        {for (final t in DocumentType.values) t.icon}.length,
        DocumentType.values.length,
      );
    });
  });
}
