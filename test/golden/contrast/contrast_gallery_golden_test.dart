// A gallery of the widgets the colour-contrast PRs change, in light and dark.
//
// The baseline images are committed with the guard. Each later PR
// regenerates only the scenes it changes, so the image diff on GitHub is the
// before and after. Tagged `golden`, so CI skips it; regenerate locally with
//   flutter test --tags golden --update-goldens test/golden/contrast
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/change_badge.dart';
import 'package:inv_tracker/core/widgets/currency_badge.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/metric_tile.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../mocks/mock_analytics_service.dart';
import '../../store_screenshots/store_screenshot_harness.dart'
    show loadStoreScreenshotFonts;
import '../golden_test_helper.dart';

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
const _gain = InvestmentStats(
  totalInvested: 1000000,
  totalReturned: 1114000,
  netCashFlow: 114000,
  absoluteReturn: 11.4,
  moic: 1.114,
  xirr: 0.114,
  cashFlowCount: 2,
  cashOnlyCount: 1,
);

const _loss = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 50000,
  netCashFlow: -50000,
  absoluteReturn: -50,
  moic: 0.5,
  xirr: -0.5258,
  cashFlowCount: 3,
);

Widget _fields() => Padding(
  padding: const EdgeInsets.all(16),
  child: Form(
    autovalidateMode: AutovalidateMode.always,
    child: Column(
      children: [
        const AppTextField(label: 'Idle', hint: 'Enter a name'),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Focused',
          hint: 'Enter a name',
          autofocus: true,
          controller: TextEditingController(text: 'Demo'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Error',
          hint: 'Enter a name',
          validator: (_) => 'Enter a name',
        ),
      ],
    ),
  ),
);

Widget _hero(
  InvestmentStats stats, {
  bool realizedOnly = false,
  int archived = 0,
}) => HeroCardContent(
  globalStats: stats,
  openStats: realizedOnly ? InvestmentStats.empty() : stats,
  closedStats: realizedOnly ? stats : InvestmentStats.empty(),
  currencyFormat: _inr,
  showRealizedOnly: realizedOnly,
  archivedCount: archived,
);

/// Scene name and content. The names are the file names. Each scene is as
/// tall as its content, on the page colour of its theme.
final _scenes = <String, ({Widget Function() build})>{
  'change_badge': (
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ChangeBadge(value: 12.5),
          ChangeBadge(value: -4.25),
          ChangeBadge(value: 0),
          ChangeBadge(value: 3.1, size: ChangeBadgeSize.small),
          ChangeBadge(value: -8, size: ChangeBadgeSize.large),
        ],
      ),
    ),
  ),
  'text_fields': (build: _fields),
  'buttons': (
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Filled'),
            ),
          ),
        ],
      ),
    ),
  ),
  'card_edges': (
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Card title'),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text('Below a divider'),
          ],
        ),
      ),
    ),
  ),
  'metric_tiles': (
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MetricTile(
            label: 'Net cash flow',
            value: '₹1,14,000',
            change: '+11.4%',
            isPositive: true,
            icon: Icons.trending_up_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          MetricTile(
            label: 'Net position',
            value: '-₹50,000',
            change: '-50.0%',
            isPositive: false,
            icon: Icons.trending_down_rounded,
            onTap: () {},
          ),
        ],
      ),
    ),
  ),
  'currency_badges': (
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CurrencyBadge(currencyCode: 'USD', compact: true),
          CurrencyBadge(
            currencyCode: 'USD',
            exchangeRate: 83.12,
            targetCurrency: 'INR',
          ),
        ],
      ),
    ),
  ),
  'type_chips': (
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: TypeSelector<InvestmentType>(
        values: InvestmentType.values,
        selectedValue: InvestmentType.bonds,
        onSelected: (_) {},
        colorBuilder: (t) => t.color,
        iconBuilder: (t) => t.icon,
        labelBuilder: (t) => t.displayName,
      ),
    ),
  ),
  'hero_card_gain': (
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: _hero(_gain, archived: 1),
    ),
  ),
  'hero_card_loss': (
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: _hero(_loss, realizedOnly: true),
    ),
  ),
};

const _sceneWidth = 400.0;
final _sceneKey = GlobalKey();

void main() {
  setUpAll(GoldenTestConfig.setup);

  for (final MapEntry(key: name, value: scene) in _scenes.entries) {
    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets('$name - $theme', (tester) async {
        // The bundled Plus Jakarta Sans files are unusable until #973 is
        // fixed, so the harness puts Roboto in their place, as it does for
        // the store screenshots. It also loads the icon font.
        await loadStoreScreenshotFonts(tester);
        await tester.setGoldenSize(const Size(_sceneWidth, 900));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privacyModeProvider.overrideWith(_PrivacyOff.new),
              currencyCodeProvider.overrideWith((ref) => 'INR'),
              analyticsServiceProvider.overrideWithValue(
                FakeAnalyticsService(),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: _sceneKey,
                    child: Builder(
                      builder: (context) => ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        // A column gives the scene unbounded height, so it
                        // is as tall as its content.
                        child: SizedBox(
                          width: _sceneWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [scene.build()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(_sceneKey),
          matchesGoldenFile('goldens/${name}_$theme.png'),
        );
      });
    }
  }
}
