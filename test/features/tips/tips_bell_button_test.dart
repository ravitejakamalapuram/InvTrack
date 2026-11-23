import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/presentation/providers/daily_tip_provider.dart';
import 'package:inv_tracker/features/tips/presentation/widgets/daily_tip_card.dart';
import 'package:inv_tracker/features/tips/presentation/widgets/tips_bell_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_analytics_service.dart';

const _tips = [
  Tip(id: 'a', title: 'Title A', body: 'Body A'),
  Tip(id: 'b', title: 'Title B', body: 'Body B'),
  Tip(id: 'c', title: 'Title C', body: 'Body C'),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Tip> pool = _tips,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      tipsPoolProvider.overrideWith((ref) async => pool),
      dailyTipClockProvider.overrideWithValue(() => DateTime(2026, 11, 18, 9)),
      dailyTipRandomProvider.overrideWithValue(Random(1)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: _Bar(), body: DailyTipCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) =>
      AppBar(actions: const [TipsBellButton()]);
}

void main() {
  testWidgets('bell shows a dot until it is opened, then lists the tips', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byTooltip('Tips, new tip'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Education, not investment advice.'), findsNWidgets(2));
    expect(find.byTooltip('Tips'), findsOneWidget);
    expect(find.byTooltip('Tips, new tip'), findsNothing);
  });

  testWidgets('a tip dismissed on the card is still in the bell', (
    tester,
  ) async {
    final c = await _pump(tester);
    final todayId = c
        .read(sharedPreferencesProvider)
        .getString(dailyTipTodayIdKey)!;
    final title = _tips.firstWhere((t) => t.id == todayId).title;

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Tip of the day'), findsNothing);
    expect(find.byTooltip('Tips'), findsOneWidget); // dismissing marks it read

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('earlier tips are listed newest first, today first', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      prefs: {
        dailyTipHistoryKey: ['a', 'b'],
        dailyTipSeenKey: ['a', 'b'],
        dailyTipTodayIdKey: 'b',
        dailyTipTodayDateKey: '2026-11-18',
      },
    );
    expect(c.read(dailyTipHistoryProvider).value!.map((t) => t.id), ['b', 'a']);
  });

  testWidgets('history survives the no-repeat set restarting', (tester) async {
    // All three seen: the next pick restarts the seen set with one id.
    final c = await _pump(
      tester,
      prefs: {
        dailyTipHistoryKey: ['a', 'b', 'c'],
        dailyTipSeenKey: ['a', 'b', 'c'],
        dailyTipTodayIdKey: 'c',
        dailyTipTodayDateKey: '2026-11-17',
      },
    );
    final ids = c.read(dailyTipHistoryProvider).value!.map((t) => t.id);
    expect(ids, hasLength(3));
    expect(ids.first, isNot('c')); // a new tip came first
  });

  testWidgets('a tip dismissed earlier today is already read', (tester) async {
    final c = await _pump(
      tester,
      prefs: {dailyTipDismissedDateKey: '2026-11-18'},
    );
    expect(c.read(dailyTipUnreadProvider), isFalse);
  });

  testWidgets('an upgrade seeds the history from the seen tips, even if '
      'today\'s tip was already dismissed', (tester) async {
    final c = await _pump(
      tester,
      prefs: {
        dailyTipSeenKey: ['a', 'b'],
        dailyTipTodayIdKey: 'b',
        dailyTipTodayDateKey: '2026-11-18',
        dailyTipDismissedDateKey: '2026-11-18',
      },
    );
    expect(c.read(dailyTipHistoryProvider).value!.map((t) => t.id), ['b', 'a']);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('no bell when there are no tips', (tester) async {
    await _pump(tester, pool: const []);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
  });

  testWidgets('unread again the next day', (tester) async {
    final c = await _pump(tester, prefs: {dailyTipReadDateKey: '2026-11-17'});
    expect(c.read(dailyTipUnreadProvider), isTrue);
    await c.read(dailyTipUnreadProvider.notifier).markRead();
    expect(c.read(dailyTipUnreadProvider), isFalse);
    expect(
      c.read(sharedPreferencesProvider).getString(dailyTipReadDateKey),
      '2026-11-18',
    );
  });

  testWidgets('long tips scroll in the sheet on a small screen with big text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 2, 480 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final longTips = [
      for (var i = 0; i < 7; i++)
        Tip(id: 't$i', title: 'Title $i', body: 'Body text ' * 40),
    ];
    await _pump(
      tester,
      pool: longTips,
      prefs: {
        dailyTipHistoryKey: [for (final t in longTips) t.id],
        dailyTipSeenKey: [for (final t in longTips) t.id],
        dailyTipTodayIdKey: 't6',
        dailyTipTodayDateKey: '2026-11-18',
      },
    );
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    // Never taller than the screen, last tip reachable by scrolling,
    // disclaimer pinned and visible.
    expect(tester.takeException(), isNull);
    expect(find.text('Education, not investment advice.'), findsWidgets);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Title 0'), findsOneWidget);
    expect(find.text('Read more'), findsWidgets);

    await tester.tap(find.text('Read more').last);
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });
}
