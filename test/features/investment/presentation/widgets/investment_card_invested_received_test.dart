// #977 option A: an open investment card that awaits a current value shows
// what was put in, what came back and the status chip. It shows no net figure,
// no minus sign and no percent (money rule 4). The same change aligns every
// card: amounts on one right edge, labels on their amount's baseline, the same
// gaps on every card, and nothing clipped at 320dp or 200% text.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import '../../../../helpers/sentinel_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// One card: the investment, its stats and its XIRR.
class _Fx {
  const _Fx(this.investment, this.stats, this.xirr);
  final InvestmentEntity investment;
  final InvestmentStats stats;
  final XirrResult xirr;

  _Fx archived() => _Fx(investment.copyWith(isArchived: true), stats, xirr);

  _Fx maturing(DateTime date) =>
      _Fx(investment.copyWith(maturityDate: date), stats, xirr);
}

InvestmentEntity _investment({
  required String id,
  required String name,
  required InvestmentType type,
  InvestmentStatus status = InvestmentStatus.open,
}) => InvestmentEntity(
  id: id,
  name: name,
  type: type,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

InvestmentStats _stats({
  required double invested,
  required double returned,
  required int count,
  DateTime? first,
  DateTime? last,
  double absoluteReturn = 0,
  double? currentValue,
  bool currentValueIsEstimate = false,
  double? currentValueRate,
  int cashOnlyCount = 0,
}) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: absoluteReturn,
  moic: invested == 0 ? 0 : returned / invested,
  xirr: 0,
  cashFlowCount: count,
  firstCashFlowDate: first ?? DateTime(2026, 1, 1),
  lastCashFlowDate: last ?? DateTime(2026, 9, 27),
  currentValue: currentValue,
  currentValueDate: currentValue == null ? null : DateTime(2026, 10, 2),
  currentValueIsEstimate: currentValueIsEstimate,
  currentValueRate: currentValueRate,
  cashOnlyCount: cashOnlyCount,
);

// Rs4,00,000 put in, Rs2,52,000 back, no value: awaiting a current value.
final _p2p = _Fx(
  _investment(
    id: 'p2p',
    name: 'P2P loan pool A',
    type: InvestmentType.p2pLending,
  ),
  _stats(invested: 400000, returned: 252000, count: 9),
  const XirrResult.exact(-0.5),
);

// Rs1,50,000 put in, nothing back: awaiting a first payout.
final _gold = _Fx(
  _investment(id: 'gold', name: 'Gold bond 2029', type: InvestmentType.bonds),
  _stats(
    invested: 150000,
    returned: 0,
    count: 1,
    first: DateTime(2026, 1, 1),
    last: DateTime(2026, 1, 1),
  ),
  const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
);

// Rs12.35 Cr put in, Rs9.88 Cr back, no value: the widest figures a card shows.
final _crore = _Fx(
  _investment(
    id: 'flat',
    name: 'Flat in Powai',
    type: InvestmentType.realEstate,
  ),
  _stats(invested: 123500000, returned: 98800000, count: 12),
  const XirrResult.exact(-0.2),
);

// Rs10 Cr put in, nothing back: a Cr-scale card whose figures are narrower than
// _crore's, to line up against it.
final _croreSmall = _Fx(
  _investment(
    id: 'plot',
    name: 'Plot in Pune',
    type: InvestmentType.realEstate,
  ),
  _stats(invested: 100000000, returned: 0, count: 2),
  const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
);

// Cr-scale cards that keep a net figure: closed, and open with a confirmed
// value. Their strip shows "Total cost: " and the amount.
final _croreClosed = _Fx(
  _investment(
    id: 'flat-closed',
    name: 'Flat in Powai',
    type: InvestmentType.realEstate,
    status: InvestmentStatus.closed,
  ),
  _stats(
    invested: 123500000,
    returned: 150000000,
    count: 12,
    absoluteReturn: 21.5,
  ),
  const XirrResult.exact(0.08),
);

final _croreConfirmed = _Fx(
  _investment(
    id: 'flat-confirmed',
    name: 'Flat in Powai',
    type: InvestmentType.realEstate,
  ),
  _stats(
    invested: 123500000,
    returned: 0,
    count: 12,
    absoluteReturn: 13.4,
    currentValue: 140000000,
  ),
  const XirrResult.exact(0.134),
);

// States that keep today's card: a net figure and a return pill.
final _confirmedValue = _Fx(
  _investment(
    id: 'fd1',
    name: 'Cumulative FD',
    type: InvestmentType.fixedDeposit,
  ),
  _stats(
    invested: 100000,
    returned: 0,
    count: 1,
    first: DateTime(2025, 10, 2),
    last: DateTime(2025, 10, 2),
    absoluteReturn: 7.185903,
    currentValue: 107185.90,
  ),
  const XirrResult.exact(0.07185903),
);

final _estimate = _Fx(
  _investment(
    id: 'fd2',
    name: 'Cumulative FD',
    type: InvestmentType.fixedDeposit,
  ),
  _stats(
    invested: 100000,
    returned: 0,
    count: 1,
    first: DateTime(2025, 10, 2),
    last: DateTime(2025, 10, 2),
    absoluteReturn: 7.185903,
    currentValue: 107185.90,
    currentValueIsEstimate: true,
    currentValueRate: 7,
  ),
  const XirrResult.exact(0.07185903),
);

_Fx _paidBack({
  String id = 'paid',
  double returned = 110000,
  InvestmentStatus status = InvestmentStatus.open,
}) => _Fx(
  _investment(
    id: id,
    name: 'Paid back FD',
    type: InvestmentType.fixedDeposit,
    status: status,
  ),
  _stats(
    invested: 100000,
    returned: returned,
    count: 2,
    first: DateTime(2023, 1, 1),
    last: DateTime(2024, 1, 1),
    absoluteReturn: 10,
    cashOnlyCount: 1,
  ),
  const XirrResult.exact(0.049),
);

final _closed = _paidBack(id: 'closed', status: InvestmentStatus.closed);

final _shortHolding = _Fx(
  _investment(
    id: 'short',
    name: 'Short FD',
    type: InvestmentType.fixedDeposit,
    status: InvestmentStatus.closed,
  ),
  _stats(
    invested: 100000,
    returned: 102000,
    count: 2,
    first: DateTime(2026, 1, 1),
    last: DateTime(2026, 1, 4),
    absoluteReturn: 2.0,
  ),
  const XirrResult.approximate(10.126388779444367),
);

/// Inter, so text is as wide as on a phone. Without it the test font is far
/// wider and every width assertion would measure the wrong thing.
Future<void> _loadInter() async {
  for (final (family, file) in [
    ('Inter_regular', 'Inter-Regular'),
    ('Inter_500', 'Inter-Medium'),
    ('Inter_600', 'Inter-SemiBold'),
    ('Inter', 'Inter-Regular'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$file.ttf'));
    await loader.load();
  }
}

/// Pumps [cards] in a list, as on the investments screen.
Future<void> _pumpCards(
  WidgetTester tester,
  List<_Fx> cards, {
  double width = 360,
  double textScale = 1.0,
  bool privacy = false,
  Brightness brightness = Brightness.light,
  bool selectionMode = false,
  bool statsFailed = false,
  String currencySymbol = '₹',
  String currencyLocale = 'en_IN',
  String currencyCode = 'INR',
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        for (final c in cards)
          if (c.investment.isArchived)
            multiCurrencyArchivedInvestmentStatsProvider(
              c.investment.id,
            ).overrideWith(
              (ref) async => c.stats.copyWith(
                xirr: c.xirr.value,
                xirrMethod: c.xirr.method,
              ),
            )
          else ...[
            investmentBasicStatsProvider(c.investment.id).overrideWith(
              (ref) => statsFailed
                  ? AsyncValue.error(Exception('offline'), StackTrace.empty)
                  : AsyncValue.data(c.stats),
            ),
            investmentXirrProvider(
              c.investment.id,
            ).overrideWith((ref) => Future.value(c.xirr)),
          ],
        currencySymbolProvider.overrideWith((ref) => currencySymbol),
        currencyFormatProvider.overrideWith(
          (ref) => NumberFormat.currency(
            locale: currencyLocale,
            symbol: currencySymbol,
            decimalDigits: 0,
          ),
        ),
        currencyCodeProvider.overrideWith((ref) => currencyCode),
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: sentinelLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // A list, not a bare body: a Scaffold body stretches a card's Column
        // to the viewport height.
        home: Scaffold(
          body: ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              for (final c in cards)
                InvestmentCard(
                  investment: c.investment,
                  isSelectionMode: selectionMode,
                  isSelected: false,
                  onTap: () {},
                  onCheckboxChanged: selectionMode ? (_) {} : null,
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

Rect _rect(WidgetTester tester, String text, [int index = 0]) =>
    tester.getRect(find.text(text).at(index));

/// Alphabetic baseline of the text, in global coordinates.
double _baseline(WidgetTester tester, String text, [int index = 0]) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(text).at(index),
  );
  // The baseline point is mapped to global coordinates, so a ledger scaled down
  // to fit measures as drawn.
  final baseline = paragraph.getDryBaseline(
    paragraph.constraints,
    TextBaseline.alphabetic,
  )!;
  return paragraph.localToGlobal(Offset(0, baseline)).dy;
}

String _label(WidgetTester tester, [int index = 0]) =>
    tester.getSemantics(find.byType(GlassCard).at(index)).label;

/// The chip's box: the Container around the status text.
Finder _chipBox(String status) => find
    .ancestor(of: find.text(status), matching: find.byType(Container))
    .first;

/// The box beside the tile that holds the name and the chips: the width the
/// name has.
double _nameBox(WidgetTester tester, String name) => tester
    .getRect(
      find.ancestor(of: find.text(name), matching: find.byType(Column)).first,
    )
    .width;

/// A name keeps room for about nine characters and an ellipsis: 96dp at normal
/// text size, growing with the text so it holds as many characters at any size.
double _minNameBox(double textScale) => 96 * textScale;

/// Every text lies inside the card.
void _expectInsideCard(WidgetTester tester) {
  final card = tester.getRect(find.byType(GlassCard));
  final texts = find.descendant(
    of: find.byType(GlassCard),
    matching: find.byType(Text),
  );
  for (var i = 0; i < texts.evaluate().length; i++) {
    final rect = tester.getRect(texts.at(i));
    final data = tester.widget<Text>(texts.at(i)).data;
    expect(rect.left, greaterThanOrEqualTo(card.left), reason: data);
    expect(rect.right, lessThanOrEqualTo(card.right), reason: data);
    expect(rect.bottom, lessThanOrEqualTo(card.bottom), reason: data);
  }
}

/// What fitting means: no overflow, the name keeps its room and every text lies
/// inside the card.
void _expectFits(
  WidgetTester tester, {
  required String name,
  required double textScale,
  double? minNameBox,
}) {
  expect(tester.takeException(), isNull);
  expect(
    _nameBox(tester, name),
    greaterThanOrEqualTo(minNameBox ?? _minNameBox(textScale)),
    reason: 'the name box is too narrow',
  );
  _expectInsideCard(tester);
}

/// The name keeps [_minNameBox], or all the room that stacking the figures
/// under it can give: the card less its border, padding, checkbox and tile.
void _expectNameRoom(
  WidgetTester tester, {
  required String name,
  required double textScale,
  required bool selectionMode,
}) {
  final card = tester.getRect(find.byType(GlassCard));
  final stackedRoom =
      card.width -
      2 -
      2 * AppSpacing.md -
      (selectionMode ? AppSizes.minTouchTarget + AppSpacing.xs : 0) -
      AppSizes.iconXl -
      AppSpacing.md;
  expect(
    _nameBox(tester, name),
    greaterThanOrEqualTo(math.min(_minNameBox(textScale), stackedRoom) - 0.01),
    reason: 'the name box is too narrow',
  );
}

/// Whether the badge has room for its longest word ("MATURITY") on one line.
/// Beside the checkbox and tile, at 280dp with 130% text or 320dp with 200%
/// text, it has not: the word itself then breaks across lines, whole.
bool _badgeFitsItsLongestWord(double width, double textScale, bool selection) =>
    !selection ||
    (width > 280 || textScale < 1.3) && (width > 320 || textScale < 2.0);

/// A status label is content: it wraps, it is never cut. No overflow, no text
/// outside the card, the label inside its own badge, not one line dropped, and
/// two lines at most wherever its longest word fits.
void _expectBadgeWhole(
  WidgetTester tester,
  String label, {
  required String name,
  required double width,
  required double textScale,
  required bool selectionMode,
}) {
  expect(tester.takeException(), isNull);
  _expectInsideCard(tester);
  _expectNameRoom(
    tester,
    name: name,
    textScale: textScale,
    selectionMode: selectionMode,
  );
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason:
        '"$label" is cut: ${paragraph.size.width}dp drawn of '
        '${paragraph.getMaxIntrinsicWidth(double.infinity)}dp',
  );
  final style = tester.widget<Text>(find.text(label)).style!;
  final lines =
      (paragraph.size.height / (style.fontSize! * textScale * style.height!))
          .round();
  if (_badgeFitsItsLongestWord(width, textScale, selectionMode)) {
    expect(
      lines,
      lessThanOrEqualTo(2),
      reason: '"$label" wraps to $lines lines',
    );
  }
  final badge = tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  final text = _rect(tester, label);
  expect(text.left, greaterThanOrEqualTo(badge.left));
  expect(text.right, lessThanOrEqualTo(badge.right));
}

void main() {
  setUpAll(_loadInter);

  group('awaiting a current value shows invested and received', () {
    testWidgets('P2P card: invested, received, then the chip', (tester) async {
      await _pumpCards(tester, [_p2p]);

      expect(find.text('₹4 L'), findsOneWidget);
      expect(find.text('total cost'), findsOneWidget);
      expect(find.text('₹2.52 L'), findsOneWidget);
      expect(find.text('received'), findsOneWidget);
      expect(find.text('Awaiting current value'), findsOneWidget);
      // The strip no longer repeats the invested amount.
      expect(find.text('Total cost: '), findsNothing);

      final invested = _rect(tester, '₹4 L');
      final received = _rect(tester, '₹2.52 L');
      final chip = tester.getRect(_chipBox('Awaiting current value'));
      expect(invested.top, lessThan(received.top));
      expect(received.bottom, lessThanOrEqualTo(chip.top));
    });

    testWidgets(
      'gold card: invested, nothing received, awaiting first payout',
      (tester) async {
        await _pumpCards(tester, [_gold]);

        expect(find.text('₹1.5 L'), findsOneWidget);
        expect(find.text('total cost'), findsOneWidget);
        expect(find.text('₹0'), findsOneWidget);
        expect(find.text('received'), findsOneWidget);
        expect(find.text('Awaiting first payout'), findsOneWidget);
      },
    );

    testWidgets('an archived awaiting card shows the same', (tester) async {
      await _pumpCards(tester, [_p2p.archived()]);

      expect(find.text('₹4 L'), findsOneWidget);
      expect(find.text('total cost'), findsOneWidget);
      expect(find.text('₹2.52 L'), findsOneWidget);
      expect(find.text('received'), findsOneWidget);
      expect(find.text('Awaiting current value'), findsOneWidget);
      expect(find.text('Total cost: '), findsNothing);
    });

    for (final fx in [_p2p, _gold]) {
      testWidgets('${fx.investment.name}: no net figure, minus, plus, percent '
          'or dash', (tester) async {
        await _pumpCards(tester, [fx]);

        final inCard = find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Text),
        );
        for (final symbol in ['-', '+', '%', '—']) {
          expect(
            find.descendant(
              of: find.byType(GlassCard),
              matching: find.textContaining(symbol),
            ),
            findsNothing,
            reason:
                'a "$symbol" is drawn: ${[for (final e in inCard.evaluate()) (e.widget as Text).data]}',
          );
        }
        expect(find.text('-₹1.48 L'), findsNothing);
        final label = _label(tester);
        expect(label, isNot(contains('Current value')));
        expect(label, isNot(contains('negative')));
      });
    }

    testWidgets('the semantics label speaks invested and received', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p, _gold]);

      expect(
        _label(tester, 0),
        contains(
          'Total cost: 4 lakh rupees. Received: 2.52 lakh rupees. '
          'Returns: Awaiting current value',
        ),
      );
      expect(
        _label(tester, 1),
        contains(
          'Total cost: 1.5 lakh rupees. Received: 0 rupees. '
          'Returns: Awaiting first payout',
        ),
      );
      expect(_label(tester, 0), isNot(contains('Current value')));
      expect(_label(tester, 1), isNot(contains('Current value')));
    });

    testWidgets('long-press on an amount still shows the exact amount', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p]);

      await tester.longPress(find.text('₹4 L'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('privacy mode', () {
    for (final fx in [_p2p, _gold]) {
      testWidgets('${fx.investment.name}: both figures are masked, words and '
          'chip stay', (tester) async {
        await _pumpCards(tester, [fx], privacy: true);

        expect(find.textContaining('₹'), findsNothing);
        expect(find.text('•••••'), findsNWidgets(2));
        expect(find.text('total cost'), findsOneWidget);
        expect(find.text('received'), findsOneWidget);
        expect(find.textContaining('Awaiting'), findsOneWidget);

        final label = _label(tester);
        expect(
          label,
          contains(
            'Total cost: $sentinelHiddenAmount. Received: $sentinelHiddenAmount. '
            'Returns: '
            'Awaiting',
          ),
        );
        for (final leak in [
          '4 lakh',
          '2.52',
          '1.5 lakh',
          '0 rupees',
          'rupees',
        ]) {
          expect(label, isNot(contains(leak)), reason: leak);
        }
      });
    }

    testWidgets('a numeric return is masked in the semantics label', (
      tester,
    ) async {
      await _pumpCards(tester, [_confirmedValue], privacy: true);

      final label = _label(tester);
      expect(label, contains(sentinelHiddenPercentage));
      expect(label, isNot(contains('7.2')));
      expect(label, isNot(contains('7.19')));
    });
  });

  group('alignment', () {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('amounts share one right edge on every card '
            '(${width}dp, ${scale}x)', (tester) async {
          await _pumpCards(
            tester,
            [_p2p, _gold],
            width: width,
            textScale: scale,
          );

          // R1: within a card and across cards.
          expect(
            _rect(tester, '₹4 L').right,
            closeTo(_rect(tester, '₹2.52 L').right, 0.01),
          );
          expect(
            _rect(tester, '₹1.5 L').right,
            closeTo(_rect(tester, '₹0').right, 0.01),
          );
          expect(
            _rect(tester, '₹4 L').right,
            closeTo(_rect(tester, '₹1.5 L').right, 0.01),
          );
          expect(
            _rect(tester, '₹2.52 L').right,
            closeTo(_rect(tester, '₹0').right, 0.01),
          );
          // The words line up too: same left edge for "invested", same right
          // edge for "received".
          expect(
            _rect(tester, 'total cost', 0).left,
            closeTo(_rect(tester, 'total cost', 1).left, 0.01),
          );
          expect(
            _rect(tester, 'received', 0).right,
            closeTo(_rect(tester, 'received', 1).right, 0.01),
          );
          // The same spacing on every card: the name sits the same distance
          // from its card's top and left edge.
          final cards = find.byType(GlassCard);
          final first = tester.getRect(cards.at(0));
          final second = tester.getRect(cards.at(1));
          final name1 = _rect(tester, 'P2P loan pool A');
          final name2 = _rect(tester, 'Gold bond 2029');
          expect(
            name1.left - first.left,
            closeTo(name2.left - second.left, 0.01),
          );
          expect(name1.top - first.top, closeTo(name2.top - second.top, 0.01));
        });

        testWidgets('each word shares its amount\'s baseline '
            '(${width}dp, ${scale}x)', (tester) async {
          await _pumpCards(tester, [_p2p], width: width, textScale: scale);

          // R2
          expect(
            _baseline(tester, '₹4 L'),
            closeTo(_baseline(tester, 'total cost'), 0.01),
          );
          expect(
            _baseline(tester, '₹2.52 L'),
            closeTo(_baseline(tester, 'received'), 0.01),
          );
        });
      }
    }

    testWidgets('the name and the invested figure share a first baseline', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p], width: 360);

      // R3, side by side
      expect(
        _baseline(tester, 'P2P loan pool A'),
        closeTo(_baseline(tester, '₹4 L'), 0.01),
      );
    });

    testWidgets('the chip, the words and the row end on one edge', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p, _gold], width: 360);

      // R4: the chip box ends where the longest word ends, which is the right
      // padding (16) and the card border (1) in from the card.
      for (var i = 0; i < 2; i++) {
        final card = tester.getRect(find.byType(GlassCard).at(i));
        final status = i == 0
            ? 'Awaiting current value'
            : 'Awaiting first payout';
        final chip = tester.getRect(_chipBox(status));
        expect(chip.right, closeTo(_rect(tester, 'received', i).right, 0.01));
        expect(chip.right, closeTo(card.right - AppSpacing.md - 1, 0.01));
      }
    });

    testWidgets('the chip sits one xxs below the ledger', (tester) async {
      await _pumpCards(tester, [_p2p], width: 360);

      // R5: gaps come from AppSpacing.
      final ledger = tester.getRect(find.byType(Table));
      final chip = tester.getRect(_chipBox('Awaiting current value'));
      expect(chip.top - ledger.bottom, closeTo(AppSpacing.xxs, 0.01));
    });

    testWidgets('on a narrow card the figures stack under the name, still on '
        'the right edge', (tester) async {
      await _pumpCards(tester, [_p2p], width: 320, textScale: 2.0);

      final name = _rect(tester, 'P2P loan pool A');
      final invested = _rect(tester, '₹4 L');
      final card = tester.getRect(find.byType(GlassCard));
      expect(invested.top, greaterThanOrEqualTo(name.bottom));
      expect(
        tester.getRect(_chipBox('Awaiting current value')).right,
        closeTo(card.right - AppSpacing.md - 1, 0.01),
      );
    });
  });

  group('the status chip', () {
    testWidgets('is 12 sp, in the secondary text colour (light)', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p]);

      final text = tester.widget<Text>(find.text('Awaiting current value'));
      expect(text.style?.fontSize, 12);
      expect(text.style?.color, AppColors.neutral600Light);
    });

    testWidgets('is 12 sp, in the secondary text colour (dark)', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p], brightness: Brightness.dark);

      final text = tester.widget<Text>(find.text('Awaiting current value'));
      expect(text.style?.fontSize, 12);
      expect(text.style?.color, AppColors.neutral400Dark);
    });

    testWidgets('wraps to two lines instead of widening the column', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p], width: 360);

      final chip = tester.getRect(_chipBox('Awaiting current value'));
      expect(chip.width, lessThanOrEqualTo(104));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Awaiting current value'),
      );
      final text = tester.widget<Text>(find.text('Awaiting current value'));
      final oneLine = 12 * (text.style?.height ?? 1);
      expect(paragraph.size.height, greaterThan(oneLine * 1.5));
    });
  });

  group('every state fits', () {
    final states = <String, _Fx>{
      'awaiting current value': _p2p,
      'awaiting first payout': _gold,
      'confirmed value': _confirmedValue,
      'estimated value': _estimate,
      'paid back, so far': _paidBack(),
      'closed': _closed,
      'short holding': _shortHolding,
    };
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final entry in states.entries) {
          testWidgets('${entry.key} at ${width}dp, ${scale}x', (tester) async {
            await _pumpCards(
              tester,
              [entry.value],
              width: width,
              textScale: scale,
            );

            _expectFits(
              tester,
              name: entry.value.investment.name,
              textScale: scale,
            );
          });
        }
      }
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('a card whose stats failed to load fits 320dp at ${scale}x', (
        tester,
      ) async {
        await _pumpCards(
          tester,
          [_p2p],
          width: 320,
          textScale: scale,
          statsFailed: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Added'), findsOneWidget);
        expect(find.text('View Details'), findsOneWidget);
      });
    }

    for (final selection in [false, true]) {
      testWidgets('tap targets are 48dp and labelled at 320dp, 2x'
          '${selection ? ' in selection mode' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpCards(
          tester,
          [_p2p, _gold],
          width: 320,
          textScale: 2.0,
          selectionMode: selection,
        );

        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  // The figures decide whether the name keeps its room beside them, measured
  // on what is drawn: Cr-scale amounts stack under the name where short ones
  // sit beside it, and masked figures count as the dots they are.
  group('a wide figure never squeezes the name', () {
    for (final (width, scale) in [
      (280.0, 1.0),
      (320.0, 1.0),
      (320.0, 1.15),
      (340.0, 1.3),
      (360.0, 1.3),
      (320.0, 2.0),
    ]) {
      for (final privacy in [false, true]) {
        testWidgets('Cr-scale card at ${width}dp, ${scale}x'
            '${privacy ? ', privacy mode' : ''}', (tester) async {
          await _pumpCards(
            tester,
            [_crore],
            width: width,
            textScale: scale,
            privacy: privacy,
          );

          _expectFits(tester, name: 'Flat in Powai', textScale: scale);
        });
      }
    }

    for (final (width, scale) in [
      (360.0, 1.0),
      (320.0, 1.0),
      (360.0, 1.3),
      (320.0, 1.3),
    ]) {
      for (final fx in [_p2p, _crore, _confirmedValue]) {
        testWidgets('selection mode: ${fx.investment.name} at ${width}dp, '
            '${scale}x', (tester) async {
          await _pumpCards(
            tester,
            [fx],
            width: width,
            textScale: scale,
            selectionMode: true,
          );

          _expectFits(tester, name: fx.investment.name, textScale: scale);
        });
      }
    }

    // 340dp, 1.0x: "₹12.35 Cr invested" is too wide to leave the name its
    // room; the five dots that replace it in privacy mode are not.
    testWidgets('Cr-scale figures drop under the name', (tester) async {
      await _pumpCards(tester, [_crore], width: 340);

      expect(
        _rect(tester, '₹12.35 Cr').top,
        greaterThanOrEqualTo(_rect(tester, 'Flat in Powai').bottom),
      );
    });

    testWidgets('masked figures are measured as the dots drawn, so they sit '
        'beside the name', (tester) async {
      await _pumpCards(tester, [_crore], width: 340, privacy: true);

      expect(
        _rect(tester, '•••••').top,
        lessThan(_rect(tester, 'Flat in Powai').bottom),
      );
    });

    testWidgets('in privacy mode the layout does not depend on the amounts', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p, _crore], width: 340, privacy: true);

      expect(
        _nameBox(tester, 'P2P loan pool A'),
        closeTo(_nameBox(tester, 'Flat in Powai'), 0.01),
      );
    });
  });

  group('maturity badge', () {
    final soon = DateTime(2026, 10, 23); // the reference date plus 12 days
    final past = DateTime(2026, 10, 1);

    void badgeFits(
      String label,
      _Fx fx,
      double width,
      double scale, {
      bool privacy = false,
    }) {
      testWidgets('"$label" on ${fx.investment.name} at ${width}dp, ${scale}x'
          '${privacy ? ', privacy mode' : ''}', (tester) async {
        await _pumpCards(
          tester,
          [fx],
          width: width,
          textScale: scale,
          privacy: privacy,
        );

        expect(find.text(label), findsOneWidget);
        _expectFits(tester, name: fx.investment.name, textScale: scale);
        // The label stays inside its own badge.
        final badge = tester.getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        final text = _rect(tester, label);
        expect(text.left, greaterThanOrEqualTo(badge.left));
        expect(text.right, lessThanOrEqualTo(badge.right));
      });
    }

    for (final (width, scale) in [
      (320.0, 1.0),
      (320.0, 1.15),
      (320.0, 2.0),
      (360.0, 1.0),
      (360.0, 1.15),
      (360.0, 1.3),
    ]) {
      badgeFits('12d TO MATURITY', _p2p.maturing(soon), width, scale);
    }
    for (final (width, scale) in [(320.0, 1.0), (320.0, 1.15), (360.0, 1.3)]) {
      badgeFits('12d TO MATURITY', _crore.maturing(soon), width, scale);
    }
    badgeFits(
      '12d TO MATURITY',
      _crore.maturing(soon),
      320,
      2.0,
      privacy: true,
    );
    badgeFits('MATURED', _p2p.maturing(past), 320, 1.15);
    badgeFits('MATURED', _gold.maturing(past), 320, 2.0);
    badgeFits(
      'MATURES TODAY',
      _gold.maturing(DateTime(2026, 10, 11)),
      320,
      2.0,
    );

    testWidgets('the whole label shows when there is room', (tester) async {
      await _pumpCards(tester, [_gold.maturing(soon)], width: 411);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('12d TO MATURITY'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // WCAG 1.4.4: a status label is content. It wraps to a second line instead of
  // ending in an ellipsis, at every width and text size, selection and privacy
  // mode included.
  group('the maturity badge keeps its whole label', () {
    final badges = <String, DateTime>{
      '12d TO MATURITY': DateTime(2026, 10, 23),
      'MATURED': DateTime(2026, 10, 1),
      'MATURES TODAY': DateTime(2026, 10, 11),
    };
    final fixtures = <String, _Fx>{
      'Cr-scale card': _crore,
      'P2P card': _p2p,
      'gold card': _gold,
    };
    // (width, text scale, selection mode)
    final cells = <(double, double, bool)>[
      (340, 1.0, false),
      (360, 1.0, false),
      (360, 1.15, false),
      (411, 1.3, false),
      (320, 2.0, false),
      (280, 1.0, true),
      (280, 2.0, true),
      (320, 1.0, true),
      (320, 2.0, true),
    ];

    void whole(
      String label,
      DateTime maturity,
      String fixtureName,
      _Fx fx,
      (double, double, bool) cell,
      bool privacy,
    ) {
      final (width, scale, selection) = cell;
      testWidgets('"$label" on the $fixtureName at ${width}dp, ${scale}x'
          '${selection ? ', selection mode' : ''}'
          '${privacy ? ', privacy mode' : ''}', (tester) async {
        await _pumpCards(
          tester,
          [fx.maturing(maturity)],
          width: width,
          textScale: scale,
          privacy: privacy,
          selectionMode: selection,
        );

        _expectBadgeWhole(
          tester,
          label,
          name: fx.investment.name,
          width: width,
          textScale: scale,
          selectionMode: selection,
        );
      });
    }

    for (final badge in badges.entries) {
      for (final fixture in fixtures.entries) {
        for (final cell in cells) {
          for (final privacy in [false, true]) {
            whole(
              badge.key,
              badge.value,
              fixture.key,
              fixture.value,
              cell,
              privacy,
            );
          }
        }
      }
    }

    // The whole probe grid for the widest badge on the widest card.
    for (final width in [280.0, 320.0, 340.0, 360.0, 411.0]) {
      for (final scale in [1.0, 1.15, 1.3, 2.0]) {
        for (final selection in [false, true]) {
          for (final privacy in [false, true]) {
            testWidgets('grid: "12d TO MATURITY" on the Cr-scale card at '
                '${width}dp, ${scale}x${selection ? ', selection mode' : ''}'
                '${privacy ? ', privacy mode' : ''}', (tester) async {
              await _pumpCards(
                tester,
                [_crore.maturing(badges.values.first)],
                width: width,
                textScale: scale,
                privacy: privacy,
                selectionMode: selection,
              );

              _expectBadgeWhole(
                tester,
                '12d TO MATURITY',
                name: _crore.investment.name,
                width: width,
                textScale: scale,
                selectionMode: selection,
              );
            });
          }
        }
      }
    }
  });

  // A stacked ledger is as wide as its widest line and never shrinks by itself;
  // a currency symbol or a longer unit pushed a figure into the card's padding
  // and, at 200% text, out of the card where its clip cut the figure.
  group('stacked figures stay inside the card in any currency', () {
    for (final (symbol, locale, code) in [
      ('₹', 'en_IN', 'INR'),
      ('Rp', 'id_ID', 'IDR'),
      ('CHF', 'de_CH', 'CHF'),
      ('KSh', 'en_KE', 'KES'),
      ('AED', 'en_AE', 'AED'),
    ]) {
      for (final selection in [false, true]) {
        testWidgets('$symbol Cr-scale card at 280dp, 2.0x'
            '${selection ? ', selection mode' : ''}', (tester) async {
          await _pumpCards(
            tester,
            [_crore],
            width: 280,
            textScale: 2.0,
            selectionMode: selection,
            currencySymbol: symbol,
            currencyLocale: locale,
            currencyCode: code,
          );

          expect(tester.takeException(), isNull);
          // Inside the card's border and its 16dp padding, not just inside the
          // card.
          final content = tester
              .getRect(find.byType(GlassCard))
              .deflate(AppSpacing.md + 1);
          final figures = find.descendant(
            of: find.byType(Table),
            matching: find.byType(Text),
          );
          expect(figures, findsNWidgets(4));
          for (var i = 0; i < 4; i++) {
            final rect = tester.getRect(figures.at(i));
            final data = tester.widget<Text>(figures.at(i)).data;
            expect(
              rect.left,
              greaterThanOrEqualTo(content.left - 0.01),
              reason:
                  '"$data" starts at ${rect.left}, content at ${content.left}',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(content.right + 0.01),
              reason:
                  '"$data" ends at ${rect.right}, content at ${content.right}',
            );
          }
          _expectInsideCard(tester);
        });
      }
    }

    // R1 and R2 where no scaling is needed: stacked Cr-scale cards still share
    // one right edge and each word sits on its amount's baseline.
    testWidgets('stacked Cr-scale cards keep one right edge and the baselines '
        '(340dp, 1.0x)', (tester) async {
      await _pumpCards(tester, [_crore, _croreSmall], width: 340);

      expect(tester.takeException(), isNull);
      expect(
        _rect(tester, '₹12.35 Cr').right,
        closeTo(_rect(tester, '₹10 Cr').right, 0.01),
      );
      expect(
        _rect(tester, '₹9.88 Cr').right,
        closeTo(_rect(tester, '₹0').right, 0.01),
      );
      for (final (amount, word, i) in [
        ('₹12.35 Cr', 'total cost', 0),
        ('₹9.88 Cr', 'received', 0),
        ('₹10 Cr', 'total cost', 1),
        ('₹0', 'received', 1),
      ]) {
        expect(
          _baseline(tester, amount),
          closeTo(_baseline(tester, word, i), 0.01),
          reason: '$amount and $word',
        );
      }
    });

    // The ledger scales to the room here (265.7dp of figures in 214dp), so its
    // baselines are measured after the scale. Only a card that scales moves its
    // amounts: the words are smaller there, so across cards the amounts' right
    // edge is not shared, the words' edge is.
    testWidgets(
      'a scaled-down ledger keeps its right edge, its amounts together '
      'and the baselines (280dp, 2.0x)',
      (tester) async {
        await _pumpCards(
          tester,
          [_crore, _croreSmall],
          width: 280,
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        final content = tester
            .getRect(find.byType(GlassCard).first)
            .deflate(AppSpacing.md + 1);
        expect(
          _rect(tester, '₹12.35 Cr').right,
          closeTo(_rect(tester, '₹9.88 Cr').right, 0.01),
        );
        for (final (word, i) in [
          ('total cost', 0),
          ('received', 0),
          ('total cost', 1),
          ('received', 1),
        ]) {
          expect(_rect(tester, word, i).right, closeTo(content.right, 0.01));
        }
        for (final (amount, word, i) in [
          ('₹12.35 Cr', 'total cost', 0),
          ('₹9.88 Cr', 'received', 0),
          ('₹10 Cr', 'total cost', 1),
          ('₹0', 'received', 1),
        ]) {
          expect(
            _baseline(tester, amount),
            closeTo(_baseline(tester, word, i), 0.01),
            reason: '$amount and $word',
          );
        }
      },
    );

    testWidgets('Rp figures keep one right edge and the baselines (360dp, '
        '1.0x)', (tester) async {
      await _pumpCards(
        tester,
        [_p2p, _gold],
        currencySymbol: 'Rp',
        currencyLocale: 'id_ID',
        currencyCode: 'IDR',
      );

      expect(tester.takeException(), isNull);
      final words = find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'total cost' || w.data == 'received'),
      );
      expect(words, findsNWidgets(4));
      final invested = find.text('total cost');
      final received = find.text('received');
      expect(
        tester.getRect(invested.at(0)).left,
        closeTo(tester.getRect(invested.at(1)).left, 0.01),
      );
      expect(
        tester.getRect(received.at(0)).right,
        closeTo(tester.getRect(received.at(1)).right, 0.01),
      );
      for (var i = 0; i < 2; i++) {
        final card = tester.getRect(find.byType(GlassCard).at(i));
        final table = tester.getRect(find.byType(Table).at(i));
        expect(table.right, closeTo(card.right - AppSpacing.md - 1, 0.01));
      }
    });
  });

  // The strip's "Total cost: " and amount are one group that cannot be cut, so it
  // must be allowed to wrap rather than run past the card on a Cr-scale card.
  group('the bottom strip fits a Cr-scale invested amount', () {
    final cards = <String, _Fx>{
      'closed': _croreClosed,
      'confirmed value': _croreConfirmed,
    };
    for (final card in cards.entries) {
      for (final (width, scale) in [(280.0, 2.0), (280.0, 1.3), (320.0, 2.0)]) {
        testWidgets('${card.key} Cr-scale card at ${width}dp, ${scale}x', (
          tester,
        ) async {
          await _pumpCards(
            tester,
            [card.value],
            width: width,
            textScale: scale,
          );

          expect(find.text('Total cost: '), findsOneWidget);
          expect(tester.takeException(), isNull);
          _expectInsideCard(tester);
        });
      }
    }
    // A wrapped money figure reads as a different amount ("CHF 123" over
    // ".5M"), so the amount scales down instead of wrapping, in every currency.
    for (final (symbol, locale, code) in [
      ('₹', 'en_IN', 'INR'),
      ('Rp', 'id_ID', 'IDR'),
      ('CHF', 'de_CH', 'CHF'),
    ]) {
      for (final card in cards.entries) {
        testWidgets('the invested amount stays on one line: $symbol, '
            '${card.key}, 280dp, 2.0x', (tester) async {
          await _pumpCards(
            tester,
            [card.value],
            width: 280,
            textScale: 2.0,
            currencySymbol: symbol,
            currencyLocale: locale,
            currencyCode: code,
          );

          final amount = find.descendant(
            of: find
                .ancestor(
                  of: find.text('Total cost: '),
                  matching: find.byType(Row),
                )
                .first,
            matching: find.byType(CompactAmountText),
          );
          expect(amount, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: amount, matching: find.byType(RichText)).first,
          );
          final oneLine = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout();
          expect(
            paragraph.size.height,
            closeTo(oneLine.height, 0.5),
            reason: 'the amount wrapped onto a second line',
          );
          expect(tester.takeException(), isNull);
          _expectInsideCard(tester);
        });
      }
    }
  });

  group('selection mode', () {
    Finder tile(InvestmentType type) => find
        .ancestor(of: find.byIcon(type.icon), matching: find.byType(Container))
        .first;

    for (final (width, scale) in [(360.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('the type tile is centred on the checkbox '
          '(${width}dp, ${scale}x)', (tester) async {
        await _pumpCards(
          tester,
          [_p2p],
          width: width,
          textScale: scale,
          selectionMode: true,
        );

        expect(
          tester.getCenter(tile(InvestmentType.p2pLending)).dy,
          closeTo(tester.getCenter(find.byType(Checkbox)).dy, 0.01),
        );
      });
    }

    testWidgets('outside selection mode the tile still hangs from the top', (
      tester,
    ) async {
      await _pumpCards(tester, [_p2p], width: 360);

      expect(
        tester.getRect(tile(InvestmentType.p2pLending)).top,
        closeTo(_rect(tester, 'P2P loan pool A').top, 0.01),
      );
    });
  });

  // Guard: every other state keeps its net figure and pill, and shows neither
  // word.
  group('other states are unchanged', () {
    Future<void> expectUnchanged(
      WidgetTester tester,
      _Fx fx, {
      required List<String> shows,
    }) async {
      await _pumpCards(tester, [fx]);
      for (final text in shows) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('total cost'), findsNothing);
      expect(find.text('received'), findsNothing);
      expect(find.textContaining('Awaiting'), findsNothing);
    }

    testWidgets('confirmed value', (tester) async {
      await expectUnchanged(
        tester,
        _confirmedValue,
        shows: ['-₹1 L', '+7.2% IRR', 'Total cost: '],
      );
    });

    testWidgets('estimated value', (tester) async {
      await expectUnchanged(
        tester,
        _estimate,
        shows: ['-₹1 L', '+7.2% Expected XIRR', 'Total cost: '],
      );
    });

    testWidgets('paid back, no value: so far', (tester) async {
      await expectUnchanged(
        tester,
        _paidBack(),
        shows: ['+₹10,000', '+4.9% IRR so far', 'Total cost: '],
      );
    });

    testWidgets('closed', (tester) async {
      await expectUnchanged(
        tester,
        _closed,
        shows: ['+₹10,000', '+4.9% IRR', 'CLOSED', 'Total cost: '],
      );
    });

    testWidgets('short holding', (tester) async {
      await expectUnchanged(
        tester,
        _shortHolding,
        shows: ['+₹2,000', '+2.0% in 3 days'],
      );
    });

    testWidgets('received exactly what was invested flips to the so-far look', (
      tester,
    ) async {
      await _pumpCards(tester, [_paidBack(returned: 100000)]);

      expect(find.textContaining('so far'), findsOneWidget);
      expect(find.text('total cost'), findsNothing);
      expect(find.text('received'), findsNothing);
    });
  });
  // #990: the name may take two lines beside the figures, so a long name is
  // not cut to "P2P loan p..." on a narrow phone.
  group('the name wraps to two lines instead of being cut', () {
    // (width, text scale, selection mode)
    final cells = <(double, double, bool)>[
      (280, 1.0, false),
      (320, 1.0, false),
      (360, 1.0, false),
      (411, 1.0, false),
      (320, 1.3, false),
      (360, 2.0, false),
      (411, 2.0, false),
      (320, 1.0, true),
    ];
    for (final (width, scale, selection) in cells) {
      testWidgets('"P2P loan pool A" shows in full at ${width}dp, ${scale}x'
          '${selection ? ', selection mode' : ''}', (tester) async {
        await _pumpCards(
          tester,
          [_p2p],
          width: width,
          textScale: scale,
          selectionMode: selection,
        );

        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(find.text('P2P loan pool A')).maxLines, 2);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('P2P loan pool A'),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'the name is cut at ${width}dp, ${scale}x',
        );
        _expectInsideCard(tester);
      });
    }
  });
}
