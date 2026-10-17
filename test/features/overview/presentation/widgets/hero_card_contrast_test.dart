// The Overview hero paints white text, a toggle and a return badge on the
// brand gradient. Each is pumped and measured over every stop of the gradient
// it can sit on, light and dark. Colour is not the only carrier of the return:
// the badge text starts with + or -.
//
// The ids below are rows of test/core/theme/contrast_pairs.dart; the guard
// finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

// Demo figures only.
InvestmentStats _stats({required double invested, required double returned}) =>
    InvestmentStats(
      totalInvested: invested,
      totalReturned: returned,
      netCashFlow: returned - invested,
      absoluteReturn: (returned - invested) / invested * 100,
      moic: returned / invested,
      xirr: (returned - invested) / invested,
      xirrMethod: XirrMethod.exact,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2024, 1, 1),
      lastCashFlowDate: DateTime(2026, 1, 1),
    );

Future<void> _pump(
  WidgetTester tester, {
  required double invested,
  required double returned,
}) async {
  final stats = _stats(invested: invested, returned: returned);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HeroCardContent(
            globalStats: stats,
            openStats: InvestmentStats.empty(),
            closedStats: stats,
            currencyFormat: _inr,
            showRealizedOnly: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Pair id -> the stop it is measured on. The ids are literal so the guard finds
// them.
const _title = {
  'hero-secondary-light-80@stop-5b4cdb': '5b4cdb',
  'hero-secondary-light-80@stop-7c3aed': '7c3aed',
  'hero-secondary-light-80@stop-9333ea': '9333ea',
};
const _labels = {
  'hero-secondary-light-60@stop-5b4cdb': '5b4cdb',
  'hero-secondary-light-60@stop-7c3aed': '7c3aed',
  'hero-secondary-light-60@stop-9333ea': '9333ea',
};
const _currencyLine = {
  'hero-secondary-light-50@stop-5b4cdb': '5b4cdb',
  'hero-secondary-light-50@stop-7c3aed': '7c3aed',
  'hero-secondary-light-50@stop-9333ea': '9333ea',
  'hero-secondary-dark-50@stop-312e81': '312e81',
};
const _infoIcon = {
  'hero-info-icon-light@stop-5b4cdb': '5b4cdb',
  'hero-info-icon-light@stop-7c3aed': '7c3aed',
  'hero-info-icon-light@stop-9333ea': '9333ea',
};
const _toggle = {
  'hero-toggle-light@stop-5b4cdb': '5b4cdb',
  'hero-toggle-light@stop-7c3aed': '7c3aed',
  'hero-toggle-light@stop-9333ea': '9333ea',
};
const _gain = {
  'hero-return-positive-light@stop-5b4cdb': '5b4cdb',
  'hero-return-positive-light@stop-7c3aed': '7c3aed',
  'hero-return-positive-light@stop-9333ea': '9333ea',
};
const _loss = {
  'hero-return-negative-light@stop-5b4cdb': '5b4cdb',
  'hero-return-negative-light@stop-7c3aed': '7c3aed',
  'hero-return-negative-light@stop-9333ea': '9333ea',
  'hero-return-negative-dark@stop-1e1b4b': '1e1b4b',
  'hero-return-negative-dark@stop-312e81': '312e81',
  'hero-return-negative-dark@stop-3b0764': '3b0764',
};

const _lightStops = <String, Color>{
  '5b4cdb': Color(0xFF5B4CDB),
  '7c3aed': Color(0xFF7C3AED),
  '9333ea': Color(0xFF9333EA),
};
const _darkStops = <String, Color>{
  '1e1b4b': Color(0xFF1E1B4B),
  '312e81': Color(0xFF312E81),
  '3b0764': Color(0xFF3B0764),
};

Color _textColor(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style!.color!;

/// The fill of the nearest decorated box behind [text].
Color _fillBehind(WidgetTester tester, Finder text) {
  final box = tester.widget<Container>(
    find.ancestor(of: text, matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

Color _inkFillBehind(WidgetTester tester, Finder text) {
  final ink = tester.widget<Ink>(
    find.ancestor(of: text, matching: find.byType(Ink)).first,
  );
  return (ink.decoration! as BoxDecoration).color!;
}

const _stops = {..._lightStops, ..._darkStops};

/// Every pair in [ids] meets 4.5:1 for [text] painted on [fill] over its stop.
void _expectReadable(
  Map<String, String> ids,
  Color text, {
  Color fill = const Color(0x00000000),
}) {
  ids.forEach((id, stop) {
    final ground = composeOver(fill, _stops[stop]!);
    expect(
      contrastRatio(text, ground),
      greaterThanOrEqualTo(kMinText),
      reason: id,
    );
  });
}

Finder get _badgeText => find
    .descendant(
      of: find.byKey(const ValueKey('hero-return-badge')),
      matching: find.byType(Text),
    )
    .first;

void main() {
  test('the hero gradients still start where the pairs were measured', () {
    expect(AppColors.heroGradient.colors, _lightStops.values.toList());
    expect(AppColors.heroGradientDark.colors, _darkStops.values.toList());
  });

  testWidgets('the title reads on every light stop', (tester) async {
    await _pump(tester, invested: 100000, returned: 120000);
    _expectReadable(
      _title,
      _textColor(tester, find.text('Net cash flow so far')),
    );
  });

  testWidgets('the stat labels read on every light stop', (tester) async {
    await _pump(tester, invested: 100000, returned: 120000);
    for (final label in ['out', 'in', 'XIRR']) {
      _expectReadable(_labels, _textColor(tester, find.text(label)));
    }
  });

  testWidgets(
    'the info icon beside the currency line reads on every light stop',
    (tester) async {
      await _pump(tester, invested: 100000, returned: 120000);
      final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline)).color!;
      _infoIcon.forEach((id, stop) {
        expect(
          contrastRatio(icon, _stops[stop]!),
          greaterThanOrEqualTo(kMinGraphic),
          reason: id,
        );
      });
    },
  );

  testWidgets('the currency line reads on the light and the dark stops', (
    tester,
  ) async {
    await _pump(tester, invested: 100000, returned: 120000);
    final colour = _textColor(
      tester,
      find.textContaining('All amounts shown in'),
    );
    _expectReadable(_currencyLine, colour);
    // Every dark stop, not only the one the audit flagged.
    _expectReadable({for (final k in _darkStops.keys) 'dark $k': k}, colour);
  });

  testWidgets('the All / Realized toggle reads on every stop', (tester) async {
    await _pump(tester, invested: 100000, returned: 120000);
    final label = find.text('All');
    final ids = {..._toggle, for (final k in _darkStops.keys) 'dark $k': k};
    _expectReadable(
      ids,
      _textColor(tester, label),
      fill: _inkFillBehind(tester, label),
    );
  });

  testWidgets('a gain badge reads on every stop', (tester) async {
    await _pump(tester, invested: 100000, returned: 120000);
    final label = _badgeText;
    expect(tester.widget<Text>(label).data, startsWith('+'));
    final ids = {..._gain, for (final k in _darkStops.keys) 'dark $k': k};
    _expectReadable(
      ids,
      _textColor(tester, label),
      fill: _fillBehind(tester, label),
    );
  });

  testWidgets('a loss badge reads on every stop', (tester) async {
    await _pump(tester, invested: 100000, returned: 60000);
    final label = _badgeText;
    // Colour is not the only carrier: the badge starts with -.
    expect(tester.widget<Text>(label).data, startsWith('-'));
    final ids = {..._loss, for (final k in _lightStops.keys) 'light $k': k};
    _expectReadable(
      ids,
      _textColor(tester, label),
      fill: _fillBehind(tester, label),
    );
  });

  testWidgets('the status chip (awaiting a value) reads on every stop', (
    tester,
  ) async {
    final open = _stats(invested: 100000, returned: 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyModeProvider.overrideWith(_PrivacyOff.new),
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HeroCardContent(
              globalStats: open,
              openStats: open,
              closedStats: InvestmentStats.empty(),
              currencyFormat: _inr,
              showRealizedOnly: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('Awaiting first payout');
    expect(label, findsOneWidget);
    _expectReadable(
      {for (final k in _stops.keys) 'status chip on $k': k},
      _textColor(tester, label),
      fill: _fillBehind(tester, label),
    );
  });
}
