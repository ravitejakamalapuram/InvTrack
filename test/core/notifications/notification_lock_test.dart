// A07 / PLAT-05: a notification tap must never open an investment screen
// over the app lock. While locked the tap lands on /lock; after unlock the
// screen it asked for opens.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/document_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../mocks/mock_analytics_service.dart';

/// Security state the test drives by hand: PIN set, app locked.
class _LockedSecurity extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(isLocked: true, hasPin: true);

  void unlock() => state = state.copyWith(isLocked: false);

  void lock() => state = state.copyWith(isLocked: true);
}

final _fd = InvestmentEntity(
  id: 'inv-1',
  name: 'HDFC FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

final _lock = find.byType(PasscodeScreen);
final _detail = find.byWidgetPredicate(
  (w) => w is InvestmentDetailScreen && w.investment.id == 'inv-1',
);
final _addCashFlow = find.byWidgetPredicate(
  (w) => w is AddTransactionScreen && w.investmentId == 'inv-1',
);
final _addIncome = find.byWidgetPredicate(
  (w) =>
      w is AddTransactionScreen &&
      w.investmentId == 'inv-1' &&
      w.initialType == CashFlowType.income,
);

void main() {
  late FakeAuthRepository authRepo;
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester, {
    bool settle = true,
    Stream<List<InvestmentEntity>>? investments,
  }) async {
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    authRepo = FakeAuthRepository(googleUser);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(null),
        allCashFlowsStreamProvider.overrideWith((ref) => Stream.value([])),
        cashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        expectedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        watchGoalByIdProvider(
          'goal-1',
        ).overrideWith((ref) => Stream.value(null)),
        authRepositoryProvider.overrideWithValue(authRepo),
        securityProvider.overrideWith(_LockedSecurity.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        analyticsObserverProvider.overrideWithValue(null),
        isReportsTabEnabledProvider.overrideWithValue(false),
        allInvestmentsProvider.overrideWith(
          (ref) => investments ?? Stream.value([_fd]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  /// The list and add screens start delayed entry animations; let them run
  /// out so no timer outlives the test.
  Future<void> drainAnimations(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  /// Pumps frames for [duration] without waiting for animations to end.
  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    const step = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < duration; t += step) {
      await tester.pump(step);
    }
  }

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<void> tap(WidgetTester tester, String payload) async {
    // Do not await: the navigator waits for frames, which only the tester
    // produces.
    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(payload);
    await tester.pumpAndSettle();
    await result;
    await tester.pumpAndSettle();
  }

  testWidgets('no portfolio frame renders before the lock while sign-in '
      'state is still loading', (tester) async {
    await pumpApp(tester, settle: false);

    // Every frame until the app settles: the lock, never the Overview.
    for (var frame = 0; frame < 20; frame++) {
      expect(find.byType(OverviewScreen), findsNothing, reason: 'frame $frame');
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.byType(OverviewScreen), findsNothing);
    expect(_lock, findsOneWidget);
  });

  testWidgets('a maturity notification tapped while locked lands on /lock, '
      'and opens the investment after unlock', (tester) async {
    await pumpApp(tester);
    expect(location(), '/lock');

    await tap(tester, NotificationPayload.maturityReminder('inv-1', 7));

    expect(location(), '/lock');
    expect(_lock, findsOneWidget);
    expect(_detail, findsNothing);

    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    expect(location(), '/investments/inv-1');
    expect(_detail, findsOneWidget);
    expect(_lock, findsNothing);
  });

  // The router redirect alone would send a goal tap to /lock and forget it;
  // only the deferral at the start of handleNotificationTap brings it back.
  testWidgets('a goal notification tapped while locked lands on /lock, and '
      'opens the goal after unlock', (tester) async {
    await pumpApp(tester);

    await tap(tester, 'goal_at_risk:goal-1');

    expect(location(), '/lock');

    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    expect(location(), '/goals/goal-1');
    expect(_lock, findsNothing);
  });

  testWidgets('an income reminder tapped while locked lands on /lock, and '
      'opens Add Cash Flow with INCOME after unlock', (tester) async {
    await pumpApp(tester);

    await tap(tester, NotificationPayload.incomeReminder('inv-1'));

    expect(location(), '/lock');
    expect(_addCashFlow, findsNothing);

    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    expect(location(), '/investments/inv-1/add-cash-flow?flowType=income');
    expect(_addIncome, findsOneWidget);
    await drainAnimations(tester);
  });

  testWidgets('a queued tap is dropped if another user is signed in at '
      'unlock', (tester) async {
    await pumpApp(tester);

    await tap(tester, NotificationPayload.maturityReminder('inv-1', 7));
    authRepo.emit(guestUser);
    await tester.pumpAndSettle();

    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    expect(_detail, findsNothing);
    expect(location(), '/');
  });

  // A tap that arrives before sign-in has resolved is kept without a user;
  // it opens for whoever is signed in at unlock.
  testWidgets('a tap made while locked before sign-in resolved opens after '
      'unlock once a user is signed in', (tester) async {
    await pumpApp(tester);
    // Signed out, the sign-in screen animates: pump a bounded time.
    authRepo.emit(null);
    await pumpFor(tester, const Duration(seconds: 1));

    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(
          NotificationPayload.maturityReminder('inv-1', 7),
        );
    expect(await result, isFalse);
    authRepo.emit(googleUser);
    await pumpFor(tester, const Duration(seconds: 1));

    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    expect(location(), '/investments/inv-1');
    expect(_detail, findsOneWidget);
  });

  testWidgets('a queued tap is dropped if another user signs in while the '
      'unlock is settling', (tester) async {
    await pumpApp(tester);

    await tap(tester, NotificationPayload.maturityReminder('inv-1', 7));
    // The replay starts at unlock and waits for a frame; the user changes
    // before that frame.
    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    authRepo.emit(guestUser);
    await tester.pumpAndSettle();

    expect(_detail, findsNothing);
    expect(location(), '/');
  });

  testWidgets('an investment loaded for one user is not opened if another '
      'user signed in meanwhile', (tester) async {
    final investments = StreamController<List<InvestmentEntity>>();
    addTearDown(investments.close);
    await pumpApp(tester, investments: investments.stream);
    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await pumpFor(tester, const Duration(seconds: 1));

    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(
          NotificationPayload.maturityReminder('inv-1', 7),
        );
    await tester.pump();
    authRepo.emit(guestUser);
    await pumpFor(tester, const Duration(seconds: 1));
    investments.add([_fd]);
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(_detail, findsNothing);
  });

  testWidgets('Add Cash Flow is not opened for an investment loaded for '
      'another user', (tester) async {
    final investments = StreamController<List<InvestmentEntity>>();
    addTearDown(investments.close);
    await pumpApp(tester, investments: investments.stream);
    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await pumpFor(tester, const Duration(seconds: 1));

    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(NotificationPayload.incomeReminder('inv-1'));
    await tester.pump();
    authRepo.emit(guestUser);
    await pumpFor(tester, const Duration(seconds: 1));
    investments.add([_fd]);
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(_addCashFlow, findsNothing);
  });

  testWidgets('the investment routes redirect to /lock while locked', (
    tester,
  ) async {
    await pumpApp(tester);

    container.read(routerProvider).go('/investments/inv-1', extra: _fd);
    await tester.pumpAndSettle();
    expect(location(), '/lock');

    container.read(routerProvider).go('/investments/inv-1/add-cash-flow');
    await tester.pumpAndSettle();
    expect(location(), '/lock');
    expect(_lock, findsOneWidget);
  });

  testWidgets('when unlocked a tap opens the investment at once', (
    tester,
  ) async {
    await pumpApp(tester);
    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    await tap(tester, NotificationPayload.maturityReminder('inv-1', 7));

    expect(location(), '/investments/inv-1');
    expect(_detail, findsOneWidget);
  });

  testWidgets('an investment open when the app locks is covered by the lock', (
    tester,
  ) async {
    await pumpApp(tester);
    final security =
        container.read(securityProvider.notifier) as _LockedSecurity;
    security.unlock();
    await tester.pumpAndSettle();
    await tap(tester, NotificationPayload.maturityReminder('inv-1', 7));
    expect(_detail, findsOneWidget);

    // Back from the background after the auto-lock time.
    security.lock();
    await tester.pumpAndSettle();

    expect(location(), '/lock');
    expect(_lock, findsOneWidget);
    expect(_detail, findsNothing);
  });

  testWidgets('a tap that arrives unlocked is deferred if the app locks '
      'while the investment loads', (tester) async {
    final investments = StreamController<List<InvestmentEntity>>();
    addTearDown(investments.close);
    await pumpApp(tester, investments: investments.stream);
    final security =
        container.read(securityProvider.notifier) as _LockedSecurity;
    security.unlock();
    // The investments have not loaded, so the Overview shows a progress
    // indicator that never settles: pump a bounded time instead.
    await pumpFor(tester, const Duration(seconds: 1));

    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(
          NotificationPayload.maturityReminder('inv-1', 7),
        );
    await tester.pump();
    security.lock();
    await pumpFor(tester, const Duration(seconds: 1));
    investments.add([_fd]);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    await tester.pumpAndSettle();

    expect(location(), '/lock');
    expect(_detail, findsNothing);

    security.unlock();
    await tester.pumpAndSettle();
    expect(location(), '/investments/inv-1');
    expect(_detail, findsOneWidget);
  });

  testWidgets('the detail route without an investment falls back to the '
      'list', (tester) async {
    await pumpApp(tester);
    (container.read(securityProvider.notifier) as _LockedSecurity).unlock();
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/investments/inv-1');
    await tester.pumpAndSettle();

    expect(location(), '/investments');
    expect(_detail, findsNothing);
    await drainAnimations(tester);
  });
}
