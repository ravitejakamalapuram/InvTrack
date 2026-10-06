// A92 (#857): an income reminder already in the notification shade stays
// there when the investment is closed on another device. Tapping it must not
// open Add Cash Flow with INCOME for a closed investment without a word.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/document_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/fake_auth_repository.dart';
import '../../mocks/mock_analytics_service.dart';
import '../../mocks/mock_notification_service.dart';

/// No PIN set, app unlocked.
class _UnlockedSecurity extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

InvestmentEntity _investment(String id, InvestmentStatus status) =>
    InvestmentEntity(
      id: id,
      name: 'P2P $id',
      type: InvestmentType.p2pLending,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
      incomeFrequency: IncomeFrequency.monthly,
    );

final _closed = _investment('inv-c', InvestmentStatus.closed);
final _open = _investment('inv-o', InvestmentStatus.open);

const _closedMessage = 'This investment is closed';

void main() {
  late ProviderContainer container;
  late FakeFlutterLocalNotificationsPlugin fakePlugin;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tz_data.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    final ids = [_closed.id, _open.id];
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(
          NotificationService(fakePlugin, prefs),
        ),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(null),
        allCashFlowsStreamProvider.overrideWith((ref) => Stream.value([])),
        for (final id in ids) ...[
          cashFlowsByInvestmentProvider(
            id,
          ).overrideWith((ref) => Stream.value([])),
          expectedCashFlowsByInvestmentProvider(
            id,
          ).overrideWith((ref) => Stream.value([])),
          documentsByInvestmentProvider(
            id,
          ).overrideWith((ref) => Stream.value([])),
        ],
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        securityProvider.overrideWith(_UnlockedSecurity.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        analyticsObserverProvider.overrideWithValue(null),
        isReportsTabEnabledProvider.overrideWithValue(false),
        allInvestmentsProvider.overrideWith(
          (ref) => Stream.value([_closed, _open]),
        ),
        archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
        valuationDateProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
    );
    addTearDown(container.dispose);
    // Start on the Investments tab: the tap is what this test is about, and
    // Overview reads more providers than it needs.
    container.read(routerProvider).go('/investments');
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
    await tester.pumpAndSettle();
  }

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<bool> tap(WidgetTester tester, String payload) async {
    // Do not await first: the navigator waits for frames, which only the
    // tester produces.
    final result = container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(payload);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final handled = await result;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    return handled;
  }

  /// The list, detail and add screens start delayed entry animations; let
  /// them run out so no timer outlives the test.
  Future<void> drainAnimations(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  group('Income reminder tap for a closed investment (A92)', () {
    testWidgets('opens the investment and says it is closed instead of '
        'opening add income', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);

      await tap(tester, NotificationPayload.incomeReminder('inv-c'));

      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(location(), '/investments/inv-c');
      expect(
        find.byWidgetPredicate(
          (w) => w is InvestmentDetailScreen && w.investment.id == 'inv-c',
        ),
        findsOneWidget,
      );
      expect(find.text(_closedMessage), findsOneWidget);
      expect(find.bySemanticsLabel(_closedMessage), findsOneWidget);

      semantics.dispose();
      await drainAnimations(tester);
    });

    testWidgets('cancels the closed investment\'s income reminder', (
      tester,
    ) async {
      await pumpApp(tester);

      await tap(tester, NotificationPayload.incomeReminder('inv-c'));

      expect(
        fakePlugin.cancelledNotificationIds,
        contains(NotificationIds.incomeReminder('inv-c')),
      );
      await drainAnimations(tester);
    });

    testWidgets('an open investment still opens Add Cash Flow with INCOME', (
      tester,
    ) async {
      await pumpApp(tester);

      await tap(tester, NotificationPayload.incomeReminder('inv-o'));

      expect(location(), '/investments/inv-o/add-cash-flow?flowType=income');
      final screen = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(screen.investmentId, 'inv-o');
      expect(screen.initialType, CashFlowType.income);
      expect(find.text(_closedMessage), findsNothing);
      expect(fakePlugin.cancelledNotificationIds, isEmpty);
      await drainAnimations(tester);
    });
  });
}
