// The investment card shows its type three ways: a tile with the type's icon, a
// chip with the type's name, and, once closed, a CLOSED chip. Colour is never
// the only carrier of the type: the icon and the name are always there. This
// test pumps the real card for every type, in both themes, and measures what it
// painted:
//
//  - the type name on its own pale chip reaches 4.5:1;
//  - the icon on the tile, at the tile's edge and at its centre where the
//    gradient has faded, reaches 3:1;
//  - the CLOSED word on its grey chip reaches 4.5:1
//    (closed-chip-text-light@grey20, and the same chip in dark).
//
// The ids in the reasons are rows of test/core/theme/contrast_pairs.dart; the
// guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

InvestmentEntity _investment(
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
}) => InvestmentEntity(
  id: 'demo',
  name: 'Demo investment',
  type: type,
  status: status,
  createdAt: DateTime(2024, 10, 1),
  updatedAt: DateTime(2024, 10, 1),
  currency: 'INR',
);

// Demo figures only.
final _stats = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 20000,
  netCashFlow: -80000,
  absoluteReturn: -80,
  moic: 0.2,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 10, 1),
  lastCashFlowDate: DateTime(2026, 10, 1),
);

Future<void> _pump(
  WidgetTester tester,
  InvestmentEntity investment,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        investmentBasicStatsProvider(
          investment.id,
        ).overrideWith((ref) => AsyncValue.data(_stats)),
        investmentXirrProvider(investment.id).overrideWith(
          (ref) => Future.value(
            const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
          ),
        ),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencyFormatProvider.overrideWith(
          (ref) => NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ),
        ),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InvestmentCard(
                investment: investment,
                isSelectionMode: false,
                isSelected: false,
                onTap: () {},
                referenceDate: DateTime(2026, 10, 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _cardGround(Brightness b) =>
    b == Brightness.dark ? AppColors.cardDark : AppColors.cardLight;

/// The fill of the nearest Container around [of] that has a plain colour,
/// composed over [ground] the way it is painted.
Color _chipFill(WidgetTester tester, Finder of, Color ground) {
  for (final element
      in find.ancestor(of: of, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the text.');
}

/// The tile's gradient stops, composed over [ground].
({Color start, Color centre}) _tile(
  WidgetTester tester,
  IconData icon,
  Color ground,
) {
  final glyph = find.byIcon(icon).first;
  for (final element
      in find
          .ancestor(of: glyph, matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
      final colors = (decoration.gradient! as LinearGradient).colors;
      return (
        start: composeOver(colors.first, ground),
        centre: composeOver(
          Color.lerp(colors.first, colors.last, 0.5)!,
          ground,
        ),
      );
    }
  }
  throw StateError('No gradient tile around the icon.');
}

String _id(InvestmentType type) => type.name;

// Literal ids, so that the guard finds them in this file.
const _tilePair = {
  'light': 'inv-tile-icon-light@gradient',
  'dark': 'inv-tile-icon-dark@gradient',
};
const _closedPair = {
  'light': 'closed-chip-text-light@grey20',
  'dark': 'closed-chip-text-dark@grey20',
};

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    for (final type in InvestmentType.values) {
      testWidgets('${_id(type)} in $theme: name and icon are readable', (
        tester,
      ) async {
        await _pump(tester, _investment(type), brightness);
        final ground = _cardGround(brightness);

        // The name stays: it is text, so the type never rests on colour alone.
        final name = find.text(type.displayName);
        expect(name, findsOneWidget);
        final text = tester.widget<Text>(name).style!.color!;
        final chip = _chipFill(tester, name, ground);
        final nameRatio = contrastRatio(text, chip);
        expect(
          nameRatio,
          greaterThanOrEqualTo(kMinText),
          reason:
              'inv-${_id(type)}-$theme@tint10: the type name is '
              '${nameRatio.toStringAsFixed(2)}:1 on its chip',
        );

        final tile = _tile(tester, type.icon, ground);
        final icon = tester.widget<Icon>(find.byIcon(type.icon).first).color!;
        for (final (where, fill) in [
          ('edge', tile.start),
          ('centre', tile.centre),
        ]) {
          final ratio = contrastRatio(icon, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(kMinGraphic),
            reason:
                '${_tilePair[theme]}: ${_id(type)} icon at the '
                'tile $where is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }

    testWidgets('a closed investment in $theme: CLOSED and its tile', (
      tester,
    ) async {
      await _pump(
        tester,
        _investment(
          InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
        ),
        brightness,
      );
      final ground = _cardGround(brightness);
      final closed = AppLocalizations.of(
        tester.element(find.byType(InvestmentCard)),
      ).closed;
      final word = find.text(closed);
      expect(word, findsOneWidget);
      final text = tester.widget<Text>(word).style!.color!;
      final chip = _chipFill(tester, word, ground);
      final ratio = contrastRatio(text, chip);
      expect(
        ratio,
        greaterThanOrEqualTo(kMinText),
        reason:
            '${_closedPair[theme]}: CLOSED is '
            '${ratio.toStringAsFixed(2)}:1 on its grey chip',
      );

      // The grey tile keeps its icon, and the icon is readable on it.
      final tile = _tile(tester, InvestmentType.fixedDeposit.icon, ground);
      final icon = tester
          .widget<Icon>(find.byIcon(InvestmentType.fixedDeposit.icon).first)
          .color!;
      for (final fill in [tile.start, tile.centre]) {
        expect(
          contrastRatio(icon, fill),
          greaterThanOrEqualTo(kMinGraphic),
          reason: '${_tilePair[theme]}: the closed tile icon',
        );
      }
    });
  }
}
