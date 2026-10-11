// The investment card paints the colours of the theme it is in. Until the
// contrast PRs change the light values, a light colour painted on the dark
// card is the only thing that can drop its ratio, so each text here is pumped
// in dark and measured on the ground it sits on.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _today = DateTime(2026, 10, 11);

InvestmentEntity _investment(
  String id, {
  InvestmentStatus status = InvestmentStatus.open,
  DateTime? maturity,
}) => InvestmentEntity(
  id: id,
  name: 'Demo $id',
  type: InvestmentType.fixedDeposit,
  status: status,
  createdAt: DateTime(2024, 10, 1),
  updatedAt: DateTime(2024, 10, 1),
  currency: 'INR',
  maturityDate: maturity,
);

// Demo figures only.
InvestmentStats _stats({
  required double invested,
  required double returned,
  double? xirr,
}) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: invested == 0 ? 0 : (returned - invested) / invested * 100,
  moic: invested == 0 ? 0 : returned / invested,
  xirr: xirr,
  xirrMethod: xirr == null ? XirrMethod.undefined : XirrMethod.exact,
  cashFlowCount: invested == 0 ? 0 : 2,
  firstCashFlowDate: DateTime(2024, 10, 1),
  lastCashFlowDate: DateTime(2026, 10, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentEntity investment,
  required InvestmentStats stats,
  XirrResult xirr = const XirrResult.undefined(
    XirrUndefinedReason.insufficientFlows,
  ),
  required Brightness brightness,
  bool statsFailed = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        investmentBasicStatsProvider(investment.id).overrideWith(
          (ref) => statsFailed
              ? AsyncValue.error(Exception('offline'), StackTrace.empty)
              : AsyncValue.data(stats),
        ),
        investmentXirrProvider(
          investment.id,
        ).overrideWith((ref) => Future.value(xirr)),
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
                referenceDate: _today,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style!.color!;

/// The tint behind [text]: the fill of the nearest Container around it that
/// has one, over [ground], the way it is painted.
Color _tintBehind(WidgetTester tester, Finder text, Color ground) {
  for (final element
      in find.ancestor(of: text, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the text.');
}

void main() {
  const dark = Brightness.dark;
  const light = Brightness.light;

  group('View Details (nothing invested yet) in dark', () {
    final none = _stats(invested: 0, returned: 0);

    for (final failed in [false, true]) {
      testWidgets(
        failed
            ? 'primary-light-in-dark: the stats-error link is primaryDark'
            : 'primary-light-in-dark: the empty-stats link is primaryDark',
        (tester) async {
          await _pump(
            tester,
            investment: _investment('a'),
            stats: none,
            brightness: dark,
            statsFailed: failed,
          );
          final link = find.text('View Details');
          expect(link, findsOneWidget);
          expect(_textColor(tester, link), AppColors.primaryDark);
        },
      );
    }

    testWidgets(
      'primary-light-in-dark@card, @card-strip and @background reach 4.5',
      (tester) async {
        await _pump(
          tester,
          investment: _investment('a'),
          stats: none,
          brightness: dark,
        );
        final link = find.text('View Details');
        final color = _textColor(tester, link);
        expect(
          contrastRatio(color, AppColors.cardDark),
          closeTo(5.39, 0.01),
          reason: 'primary-light-in-dark@card',
        );
        // The strip along the card's foot, read from the widget: a faint white
        // veil over the card in dark.
        expect(
          contrastRatio(color, _tintBehind(tester, link, AppColors.cardDark)),
          closeTo(5.01, 0.01),
          reason: 'primary-light-in-dark@card-strip',
        );
        expect(
          contrastRatio(color, AppColors.backgroundDark),
          closeTo(5.95, 0.01),
          reason: 'primary-light-in-dark@background',
        );
      },
    );
  });

  group('a loss in dark', () {
    final loss = _stats(invested: 100000, returned: 50000, xirr: -0.5258);
    const xirr = XirrResult.exact(-0.5258);
    final closed = _investment('loss', status: InvestmentStatus.closed);

    testWidgets('the net figure is errorDark', (tester) async {
      await _pump(
        tester,
        investment: closed,
        stats: loss,
        xirr: xirr,
        brightness: dark,
      );
      final net = tester.widget<CompactAmountText>(
        find.byType(CompactAmountText).first,
      );
      expect(net.style!.color, AppColors.errorDark);
      expect(
        contrastRatio(net.style!.color!, AppColors.cardDark),
        greaterThanOrEqualTo(kMinText),
      );
    });

    testWidgets('error-light-in-dark@tint10: the return pill reaches 4.5', (
      tester,
    ) async {
      await _pump(
        tester,
        investment: closed,
        stats: loss,
        xirr: xirr,
        brightness: dark,
      );
      // The pill is the only thing inside the fade that privacy mode hides.
      final text = find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.byType(Text),
      );
      expect(text, findsOneWidget);
      final color = _textColor(tester, text);
      expect(color, AppColors.errorDark);
      expect(
        contrastRatio(color, _tintBehind(tester, text, AppColors.cardDark)),
        greaterThanOrEqualTo(kMinText),
        reason: 'error-light-in-dark@tint10',
      );
    });

    testWidgets('light mode keeps errorLight', (tester) async {
      await _pump(
        tester,
        investment: closed,
        stats: loss,
        xirr: xirr,
        brightness: light,
      );
      final net = tester.widget<CompactAmountText>(
        find.byType(CompactAmountText).first,
      );
      expect(net.style!.color, AppColors.errorLight);
    });
  });

  group('maturity chips', () {
    final paid = _stats(invested: 100000, returned: 110000, xirr: 0.05);
    const xirr = XirrResult.exact(0.05);

    // Label, days from today, colour in light, colour in dark.
    final chips = [
      ('MATURED', -10, AppColors.successLight, AppColors.successDark),
      ('MATURES TODAY', 0, AppColors.warningLight, AppColors.warningDark),
      ('5d TO MATURITY', 5, AppColors.warningLight, AppColors.warningDark),
      ('20d TO MATURITY', 20, AppColors.accentLight, AppColors.accentDark),
    ];

    for (final (label, days, inLight, inDark) in chips) {
      for (final theme in [light, dark]) {
        testWidgets('$label in $theme', (tester) async {
          await _pump(
            tester,
            investment: _investment(
              'm',
              maturity: _today.add(Duration(days: days)),
            ),
            stats: paid,
            xirr: xirr,
            brightness: theme,
          );
          final text = find.text(label);
          expect(text, findsOneWidget);
          final color = _textColor(tester, text);
          expect(color, theme == dark ? inDark : inLight);
          if (theme == dark) {
            final ground = _tintBehind(tester, text, AppColors.cardDark);
            expect(
              contrastRatio(color, ground),
              greaterThanOrEqualTo(kMinText),
            );
          }
        });
      }
    }
  });
}
