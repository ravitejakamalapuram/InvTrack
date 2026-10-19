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
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/guest_link_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

const _guest = UserEntity(id: 'g1', email: '', isAnonymous: true);
const _google = UserEntity(id: 'u1', email: 'a@b.c');
const _dismissedKey = 'guest_link_banner_dismissed_at';

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
  });

  testWidgets('still hidden 13 days after a dismiss', (tester) async {
    final at = DateTime.now().subtract(const Duration(days: 13));
    await _pump(tester, prefs: {_dismissedKey: at.millisecondsSinceEpoch});
    expect(find.text('Link Google'), findsNothing);
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
}
