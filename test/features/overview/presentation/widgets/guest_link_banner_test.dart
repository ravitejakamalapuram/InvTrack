// A43 (#786): a quiet Overview banner tells guests their data lives only on
// this device and offers to link Google. Behind FeatureFlag.guestLinkBanner
// (off by default); dismissing hides it for 14 days.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/usecases/link_account_usecase.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_link_banner_provider.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/guest_link_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

const _guest = UserEntity(id: 'g1', email: '', isAnonymous: true);
const _google = UserEntity(id: 'u1', email: 'a@b.c');
const _dismissedKey = 'guest_link_banner_dismissed_at';

class _FakeLink implements LinkAccountUseCase {
  int calls = 0;

  @override
  Future<LinkAccountResult> execute() async {
    calls++;
    return const LinkAccountCancelled();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The snooze timer outlives the widget; dispose the container so the test
/// binding sees no pending timer.
Future<void> _finish(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

class _SampleOn extends SampleDataModeNotifier {
  @override
  SampleDataState build() => const SampleDataState(isActive: true);
}

Future<(ProviderContainer, FakeAnalyticsService)> _pump(
  WidgetTester tester, {
  UserEntity? user = _guest,
  bool flagOn = true,
  Map<String, Object> prefs = const {},
  bool sample = false,
  _FakeLink? link,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final analytics = FakeAnalyticsService();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      analyticsServiceProvider.overrideWithValue(analytics),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      isGuestLinkBannerEnabledProvider.overrideWithValue(flagOn),
      googleSignInInitializedProvider.overrideWith((ref) async {}),
      if (clock != null) guestLinkBannerClockProvider.overrideWithValue(clock),
      if (link != null) linkAccountUseCaseProvider.overrideWithValue(link),
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
        home: Scaffold(body: GuestLinkBanner()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (container, analytics);
}

void main() {
  group('GuestLinkBanner', () {
    test('the flag is off by default', () {
      expect(FeatureFlag.guestLinkBanner.defaultEnabled, isFalse);
    });

    testWidgets('a guest sees the banner and the impression is logged once', (
      tester,
    ) async {
      final (_, analytics) = await _pump(tester);
      expect(find.text('Your data is only on this phone'), findsOneWidget);
      expect(find.text('Link Google'), findsOneWidget);
      final shown = analytics.loggedEvents.where(
        (e) => e.name == 'guest_link_banner_shown',
      );
      expect(shown.length, 1);
    });

    testWidgets('a Google user never sees it', (tester) async {
      final (_, analytics) = await _pump(tester, user: _google);
      expect(find.text('Link Google'), findsNothing);
      expect(analytics.loggedEvents, isEmpty);
    });

    testWidgets('flag off hides it', (tester) async {
      await _pump(tester, flagOn: false);
      expect(find.text('Link Google'), findsNothing);
    });

    testWidgets('sample data mode hides it', (tester) async {
      await _pump(tester, sample: true);
      expect(find.text('Link Google'), findsNothing);
    });

    testWidgets('dismiss hides it, logs, and stores the time', (tester) async {
      final (container, analytics) = await _pump(tester);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Link Google'), findsNothing);
      expect(
        analytics.loggedEvents.where(
          (e) => e.name == 'guest_link_banner_dismissed',
        ),
        hasLength(1),
      );
      expect(
        container.read(sharedPreferencesProvider).getInt(_dismissedKey),
        isNotNull,
      );
      await _finish(tester, container);
    });

    testWidgets('still hidden 13 days after a dismiss', (tester) async {
      final at = DateTime.now().subtract(const Duration(days: 13));
      final (container, _) = await _pump(
        tester,
        prefs: {_dismissedKey: at.millisecondsSinceEpoch},
      );
      expect(find.text('Link Google'), findsNothing);
      await _finish(tester, container);
    });

    testWidgets('back after 15 days', (tester) async {
      final at = DateTime.now().subtract(const Duration(days: 15));
      await _pump(tester, prefs: {_dismissedKey: at.millisecondsSinceEpoch});
      expect(find.text('Link Google'), findsOneWidget);
    });

    testWidgets('analytics carry no names or amounts (no parameters)', (
      tester,
    ) async {
      final (_, analytics) = await _pump(tester);
      for (final e in analytics.loggedEvents) {
        expect(e.parameters ?? const {}, isEmpty);
      }
    });

    testWidgets('Link Google logs the tap and starts the link flow', (
      tester,
    ) async {
      final link = _FakeLink();
      final (_, analytics) = await _pump(tester, link: link);
      await tester.tap(find.text('Link Google'));
      await tester.pump();
      await tester.pump();
      expect(link.calls, 1);
      expect(
        analytics.loggedEvents.where(
          (e) => e.name == 'guest_link_banner_tapped',
        ),
        hasLength(1),
      );
    });

    testWidgets('comes back when the snooze ends while mounted', (
      tester,
    ) async {
      final at = DateTime.now().subtract(
        guestLinkBannerSnooze - const Duration(seconds: 2),
      );
      var offset = Duration.zero;
      await _pump(
        tester,
        prefs: {_dismissedKey: at.millisecondsSinceEpoch},
        clock: () => DateTime.now().add(offset),
      );
      expect(find.text('Link Google'), findsNothing);
      offset = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Link Google'), findsOneWidget);
    });
  });
}
