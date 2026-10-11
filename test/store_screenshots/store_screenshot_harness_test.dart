// The generator may write files that go to the Play listing, so its checks
// must fail on a broken scene. These tests feed the checks the broken states
// the app really has and expect a failure for each, plus a control that must
// pass. The real-app tests repeat the probes from the PR review: a scene that
// is missing a card, and a loss that moves onto the first screen.
@Tags(['store-screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_load_error_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../integration_test/mocks/store_demo_data.dart';
import '../../integration_test/robots/robots.dart';
import 'store_screenshot_harness.dart';

/// Pumps [body] in an app with the real localisations, like a scene.
Future<void> _pump(WidgetTester tester, Widget Function(BuildContext) body) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: Builder(builder: body)),
        ),
      ),
    ),
  );
}

void main() {
  group('expectNoLoadingOrError', () {
    // Every state the app shows while loading or after a failure on the
    // scenes' screens. Each must fail the check.
    final broken = <String, Widget Function(BuildContext)>{
      'spinner': (_) => const CircularProgressIndicator(),
      'linear progress bar': (_) => const LinearProgressIndicator(),
      'hero card skeleton': (_) => const HeroCardSkeleton(),
      'quick stats skeleton': (_) => const QuickStatsSkeleton(),
      'section card skeleton': (_) => const SectionCardSkeleton(),
      'investment card skeleton': (_) => const InvestmentCardSkeleton(),
      // A sliver, as the list screen shows it.
      'investment list skeleton': (_) => const SizedBox(
        height: 400,
        child: CustomScrollView(slivers: [InvestmentListSkeleton()]),
      ),
      'cash flow card skeleton': (_) => const CashFlowCardSkeleton(),
      'stats cards skeleton': (_) => const StatsCardsSkeleton(),
      'loading hero card': (_) => const LoadingHeroCard(),
      'overview error card (no Retry button)': (_) =>
          const OverviewErrorCard(error: 'boom'),
      'overview load error state': (_) =>
          OverviewLoadErrorState(onRetry: () {}),
      'FIRE load error card': (_) => FireLoadErrorCard(onRetry: () {}),
      'goals load error text': (c) =>
          Text(AppLocalizations.of(c).failedToLoadGoals),
      'retry text from the l10n file': (c) =>
          Text(AppLocalizations.of(c).retry),
      'error icon alone': (_) => const Icon(Icons.error_outline),
      'offline icon alone': (_) => const Icon(Icons.cloud_off_rounded),
      'build error': (_) => ErrorWidget('boom'),
    };

    for (final entry in broken.entries) {
      testWidgets('fails on ${entry.key}', (tester) async {
        await _pump(tester, entry.value);
        expect(
          () => expectNoLoadingOrError(tester, 'scene'),
          throwsA(isA<TestFailure>()),
        );
      });
    }

    testWidgets('passes on a progress bar that shows a value', (tester) async {
      // The goal and FIRE cards draw their progress this way.
      await _pump(tester, (_) => const LinearProgressIndicator(value: 0.4));
      expectNoLoadingOrError(tester, 'scene');
    });

    testWidgets('passes on a loaded screen', (tester) async {
      await _pump(
        tester,
        (_) => const Column(children: [Text('Portfolio'), Icon(Icons.add)]),
      );
      expectNoLoadingOrError(tester, 'scene');
    });
  });

  group('negativeAmountsOnScreen', () {
    Future<List<String>> scan(WidgetTester tester, Widget child) async {
      await _pump(tester, (_) => child);
      return negativeAmountsOnScreen(tester);
    }

    for (final text in [
      '-₹1 L',
      '−₹5,000',
      'Net -₹1,00,000',
      '-12.5%',
      '₹-1 L', // the sign after the symbol
      '₹ −5,000',
    ]) {
      testWidgets('finds "$text"', (tester) async {
        expect(await scan(tester, Text(text)), [text]);
      });
    }

    testWidgets('ignores gains, ranges and hyphenated names', (tester) async {
      final found = await scan(
        tester,
        const Column(
          children: [
            Text('+₹45,000'),
            Text('₹1 L'),
            Text('22.0%'),
            Text('SGB 2024-25 Series I'),
            Text('FY 2024–25'),
            Text('1 Oct - 5 Oct'),
          ],
        ),
      );
      expect(found, isEmpty);
    });

    testWidgets('ignores text below the screen', (tester) async {
      final found = await scan(
        tester,
        const Column(
          children: [
            Text('visible'),
            SizedBox(height: 5000),
            Text('-₹9,99,999'),
          ],
        ),
      );
      expect(found, isEmpty);
    });

    testWidgets('ignores text that is not painted', (tester) async {
      final found = await scan(
        tester,
        const Opacity(opacity: 0, child: Text('-₹1 L')),
      );
      expect(found, isEmpty);
    });
  });

  group('fontFallbackProblem', () {
    const bundled = StoreScreenshotFonts(
      fallbackFamilies: [],
      testFontFamilies: [],
      materialFontsFound: true,
      emojiFontPath: '/x/emoji.ttf',
    );
    const fallback = StoreScreenshotFonts(
      fallbackFamilies: ['PlusJakartaSans_600', 'PlusJakartaSans_700'],
      testFontFamilies: [],
      materialFontsFound: true,
      emojiFontPath: '/x/emoji.ttf',
    );

    test('accepts the bundled fonts', () {
      expect(fontFallbackProblem(bundled, allowFallback: false), isNull);
    });

    test('rejects a fallback and names the families', () {
      final problem = fontFallbackProblem(fallback, allowFallback: false);
      expect(problem, contains('PlusJakartaSans_600'));
      expect(problem, contains('PlusJakartaSans_700'));
      expect(problem, contains('Roboto'));
    });

    test('accepts a fallback only when it was asked for', () {
      expect(fontFallbackProblem(fallback, allowFallback: true), isNull);
    });
  });

  group('on the real app', () {
    Future<void> inApp(
      WidgetTester tester,
      StoreDemoData demo,
      Future<void> Function() body,
    ) async {
      await loadStoreScreenshotFonts(tester);
      try {
        await pumpStoreApp(tester, demo);
        await body();
      } finally {
        releaseStoreApp();
      }
    }

    final full = StoreDemoData.build(DateTime.now());
    StoreDemoData without({bool goals = true, bool fire = true}) =>
        StoreDemoData(
          investments: full.investments,
          cashFlows: full.cashFlows,
          goals: goals ? full.goals : const [],
          fireSettings: fire
              ? full.fireSettings
              : full.fireSettings.copyWith(isSetupComplete: false),
        );

    testWidgets('the Overview check passes on the full demo', (tester) async {
      await inApp(tester, full, () async {
        await expectSceneReady(tester, 'overview');
        expectOverviewCards(tester, full);
      });
    });

    testWidgets('the Overview check fails without goals', (tester) async {
      final demo = without(goals: false);
      await inApp(tester, demo, () async {
        await expectSceneReady(tester, 'overview');
        expect(
          () => expectOverviewCards(tester, demo),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    testWidgets('the Overview check fails without the FIRE card', (
      tester,
    ) async {
      final demo = without(fire: false);
      await inApp(tester, demo, () async {
        await expectSceneReady(tester, 'overview');
        expect(
          () => expectOverviewCards(tester, demo),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    testWidgets('a loss on the first screen of the list fails the scene', (
      tester,
    ) async {
      // The review's probe: one open holding dated today sorts first and
      // shows its net cash flow, which is negative while it is open.
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final probe = InvestmentEntity(
        id: 'probe-open',
        name: 'Probe FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: day,
        updatedAt: day,
        currency: 'INR',
        currentValue: 110000,
        currentValueDate: day,
      );
      final demo = StoreDemoData(
        investments: [...full.investments, probe],
        cashFlows: [
          ...full.cashFlows,
          CashFlowEntity(
            id: 'probe-flow',
            investmentId: probe.id,
            date: day,
            type: CashFlowType.invest,
            amount: 100000,
            createdAt: day,
            currency: 'INR',
          ),
        ],
        goals: full.goals,
        fireSettings: full.fireSettings,
      );
      await inApp(tester, demo, () async {
        await NavigationRobot(tester).goToInvestments();
        // Not expectLater: it must not start before the pumps have finished.
        Object? failure;
        try {
          await expectSceneReady(tester, 'investments');
        } on TestFailure catch (e) {
          failure = e;
        }
        expect(
          failure,
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('negative amount'), contains('-₹1 L')),
          ),
        );
      });
    });

    testWidgets('the demo list shows no loss on its first screen', (
      tester,
    ) async {
      await inApp(tester, full, () async {
        await NavigationRobot(tester).goToInvestments();
        await expectSceneReady(tester, 'investments');
        expect(negativeAmountsOnScreen(tester), isEmpty);
      });
    });
  });
}
