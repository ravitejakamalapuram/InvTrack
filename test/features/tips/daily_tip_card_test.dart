// Overview daily tip card: one tip a day, same tip all day, dismiss hides
// it until tomorrow, seen tips are not shown again.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/presentation/providers/daily_tip_provider.dart';
import 'package:inv_tracker/features/tips/presentation/widgets/daily_tip_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_analytics_service.dart';

const _tips = [
  Tip(id: 'a', title: 'Title A', body: 'Body A'),
  Tip(id: 'b', title: 'Title B', body: 'Body B'),
];

Future<(ProviderContainer, FakeAnalyticsService)> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  DateTime? now,
  int seed = 1,
  List<Tip> pool = _tips,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final analytics = FakeAnalyticsService();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      analyticsServiceProvider.overrideWithValue(analytics),
      tipsPoolProvider.overrideWith((ref) async => pool),
      dailyTipClockProvider.overrideWithValue(
        () => now ?? DateTime(2026, 11, 10, 9),
      ),
      dailyTipRandomProvider.overrideWithValue(Random(seed)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DailyTipCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, analytics);
}

void main() {
  testWidgets('shows a tip with label, text and the advice disclaimer', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Tip of the day'), findsOneWidget);
    expect(find.textContaining('Title '), findsOneWidget);
    expect(find.text('Education, not investment advice.'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });

  testWidgets('the same tip stays all day and is marked seen once', (
    tester,
  ) async {
    final (c, _) = await _pump(tester);
    final first = tester.widget<Text>(find.textContaining('Title ')).data;
    final sp = c.read(sharedPreferencesProvider);
    expect(sp.getStringList('daily_tip_seen_ids'), hasLength(1));

    c.invalidate(dailyTipProvider);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.textContaining('Title ')).data, first);
    expect(sp.getStringList('daily_tip_seen_ids'), hasLength(1));
  });

  testWidgets('next day shows a different, unseen tip', (tester) async {
    await _pump(
      tester,
      prefs: {
        'daily_tip_seen_ids': ['a'],
        'daily_tip_today_id': 'a',
        'daily_tip_today_date': '2026-11-09',
      },
    );
    expect(find.text('Title B'), findsOneWidget);
  });

  testWidgets('dismiss hides it for the rest of the day and logs it', (
    tester,
  ) async {
    final (c, analytics) = await _pump(tester);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Tip of the day'), findsNothing);
    expect(
      analytics.loggedEvents.map((e) => e.name),
      contains(AnalyticsEvents.dailyTipDismissed),
    );

    c.invalidate(dailyTipProvider);
    await tester.pumpAndSettle();
    expect(find.text('Tip of the day'), findsNothing);
  });

  testWidgets('shown event carries only the content id', (tester) async {
    final (_, analytics) = await _pump(tester);
    final shown = analytics.loggedEvents.where(
      (e) => e.name == AnalyticsEvents.dailyTipShown,
    );
    expect(shown, hasLength(1));
    expect(shown.single.parameters!.keys, ['tip_id']);
  });

  testWidgets('shows nothing when the pool is empty', (tester) async {
    await _pump(tester, pool: const []);
    expect(find.text('Tip of the day'), findsNothing);
  });
}
