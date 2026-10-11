// #977 option A: an open investment card that awaits a current value shows
// what was put in, what came back and the status chip. It shows no net figure,
// no minus sign and no percent (money rule 4). The same change aligns every
// card: amounts on one right edge, labels on their amount's baseline, the same
// gaps on every card, and nothing clipped at 320dp or 200% text.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
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
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyFormatProvider.overrideWith(
          (ref) => NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ),
        ),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  return paragraph.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
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

/// What fitting means: no overflow, the name keeps its room and every text lies
/// inside the card.
void _expectFits(
  WidgetTester tester, {
  required String name,
  required double textScale,
  double? minNameBox,
}) {
  expect(tester.takeException(), isNull);
  final card = tester.getRect(find.byType(GlassCard));
  expect(
    _nameBox(tester, name),
    greaterThanOrEqualTo(minNameBox ?? _minNameBox(textScale)),
    reason: 'the name box is too narrow',
  );
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

void main() {
  setUpAll(_loadInter);

  group('awaiting a current value shows invested and received', () {
    testWidgets('P2P card: invested, received, then the chip', (tester) async {
      await _pumpCards(tester, [_p2p]);

      expect(find.text('₹4 L'), findsOneWidget);
      expect(find.text('invested'), findsOneWidget);
      expect(find.text('₹2.52 L'), findsOneWidget);
      expect(find.text('received'), findsOneWidget);
      expect(find.text('Awaiting current value'), findsOneWidget);
      // The strip no longer repeats the invested amount.
      expect(find.text('Invested: '), findsNothing);

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
        expect(find.text('invested'), findsOneWidget);
        expect(find.text('₹0'), findsOneWidget);
        expect(find.text('received'), findsOneWidget);
        expect(find.text('Awaiting first payout'), findsOneWidget);
      },
    );

    testWidgets('an archived awaiting card shows the same', (tester) async {
      await _pumpCards(tester, [_p2p.archived()]);

      expect(find.text('₹4 L'), findsOneWidget);
      expect(find.text('invested'), findsOneWidget);
      expect(find.text('₹2.52 L'), findsOneWidget);
      expect(find.text('received'), findsOneWidget);
      expect(find.text('Awaiting current value'), findsOneWidget);
      expect(find.text('Invested: '), findsNothing);
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
          'Invested: 4 lakh rupees. Received: 2.52 lakh rupees. '
          'Returns: Awaiting current value',
        ),
      );
      expect(
        _label(tester, 1),
        contains(
          'Invested: 1.5 lakh rupees. Received: 0 rupees. '
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
        expect(find.text('invested'), findsOneWidget);
        expect(find.text('received'), findsOneWidget);
        expect(find.textContaining('Awaiting'), findsOneWidget);

        final label = _label(tester);
        expect(
          label,
          contains(
            'Invested: Hidden amount. Received: Hidden amount. Returns: '
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
            _rect(tester, 'invested', 0).left,
            closeTo(_rect(tester, 'invested', 1).left, 0.01),
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
            closeTo(_baseline(tester, 'invested'), 0.01),
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
      expect(find.text('invested'), findsNothing);
      expect(find.text('received'), findsNothing);
      expect(find.textContaining('Awaiting'), findsNothing);
    }

    testWidgets('confirmed value', (tester) async {
      await expectUnchanged(
        tester,
        _confirmedValue,
        shows: ['-₹1 L', '+7.2% IRR', 'Invested: '],
      );
    });

    testWidgets('estimated value', (tester) async {
      await expectUnchanged(
        tester,
        _estimate,
        shows: ['-₹1 L', '+7.2% Expected XIRR', 'Invested: '],
      );
    });

    testWidgets('paid back, no value: so far', (tester) async {
      await expectUnchanged(
        tester,
        _paidBack(),
        shows: ['+₹10,000', '+4.9% IRR so far', 'Invested: '],
      );
    });

    testWidgets('closed', (tester) async {
      await expectUnchanged(
        tester,
        _closed,
        shows: ['+₹10,000', '+4.9% IRR', 'CLOSED', 'Invested: '],
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
      expect(find.text('invested'), findsNothing);
      expect(find.text('received'), findsNothing);
    });
  });
}
