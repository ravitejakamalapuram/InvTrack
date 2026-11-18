// The Overview shows a one-time card inviting people to the Telegram tips
// channel once they have 3 investments; the same link sits in Settings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/overview/presentation/providers/telegram_invite_provider.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/telegram_invite_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

const _google = UserEntity(id: 'u1', email: 'a@b.c');
const _guest = UserEntity(id: 'g1', email: '', isAnonymous: true);

List<InvestmentEntity> _investments(int n) => List.generate(
  n,
  (i) => InvestmentEntity(
    currency: 'INR',
    id: 'inv-$i',
    name: 'FD $i',
    type: InvestmentType.fixedDeposit,
    status: InvestmentStatus.open,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
);

class _SampleOn extends SampleDataModeNotifier {
  @override
  SampleDataState build() => const SampleDataState(isActive: true);
}

Future<(ProviderContainer, FakeAnalyticsService, List<Uri>)> _pump(
  WidgetTester tester, {
  int count = 3,
  UserEntity user = _google,
  bool sample = false,
  bool launchOk = true,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final analytics = FakeAnalyticsService();
  final launched = <Uri>[];
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      analyticsServiceProvider.overrideWithValue(analytics),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      activeInvestmentsProvider.overrideWithValue(
        AsyncData(_investments(count)),
      ),
      telegramLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return launchOk;
      }),
      if (sample) sampleDataModeProvider.overrideWith(_SampleOn.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TelegramInviteCard()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (container, analytics, launched);
}

int _count(FakeAnalyticsService a, String name) =>
    a.loggedEvents.where((e) => e.name == name).length;

void main() {
  group('TelegramInviteCard', () {
    testWidgets('shows from the 3rd investment and logs the view once', (
      tester,
    ) async {
      final (_, analytics, _) = await _pump(tester);
      expect(find.text('Join our Telegram tips'), findsOneWidget);
      expect(_count(analytics, 'telegram_invite_shown'), 1);
    });

    testWidgets('hidden with only 2 investments', (tester) async {
      await _pump(tester, count: 2);
      expect(find.text('Join our Telegram tips'), findsNothing);
    });

    testWidgets('hidden in sample data mode', (tester) async {
      await _pump(tester, sample: true);
      expect(find.text('Join our Telegram tips'), findsNothing);
    });

    testWidgets('hidden while the guest backup banner shows', (tester) async {
      await _pump(tester, user: _guest);
      expect(find.text('Join our Telegram tips'), findsNothing);
    });

    testWidgets('Join opens the channel, logs, and hides the card for good', (
      tester,
    ) async {
      final (container, analytics, launched) = await _pump(tester);
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(launched.single.toString(), 'https://t.me/invtrack_tips');
      expect(_count(analytics, 'telegram_invite_tapped'), 1);
      expect(find.text('Join our Telegram tips'), findsNothing);
      expect(
        container
            .read(sharedPreferencesProvider)
            .getBool(telegramInviteDoneKey),
        true,
      );
    });

    testWidgets('dismiss hides it for good and logs', (tester) async {
      final (container, analytics, launched) = await _pump(tester);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Join our Telegram tips'), findsNothing);
      expect(launched, isEmpty);
      expect(_count(analytics, 'telegram_invite_dismissed'), 1);
      expect(
        container
            .read(sharedPreferencesProvider)
            .getBool(telegramInviteDoneKey),
        true,
      );
    });

    testWidgets('stays hidden once done', (tester) async {
      await _pump(tester, prefs: {telegramInviteDoneKey: true});
      expect(find.text('Join our Telegram tips'), findsNothing);
    });

    testWidgets('a failed launch keeps the card and tells the user', (
      tester,
    ) async {
      await _pump(tester, launchOk: false);
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(find.text('Join our Telegram tips'), findsOneWidget);
      expect(find.textContaining('t.me/invtrack_tips'), findsOneWidget);
    });
  });
}
