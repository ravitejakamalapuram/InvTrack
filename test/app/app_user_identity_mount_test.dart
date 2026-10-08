// A101: the user-ID sync must actually run in the app. Removing it from
// InvTrackerApp would otherwise pass every other test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/fake_legacy_currency_firestore.dart';
import '../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  testWidgets('InvTrackerApp clears both user IDs when no one is signed in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final firestore = FakeLegacyCurrencyFirestore();
    final analytics = MockAnalyticsService();
    final crashlytics = _MockCrashlyticsService();
    when(() => analytics.setUserId(any())).thenAnswer((_) async {});
    when(() => crashlytics.clearUserIdentifier()).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          analyticsServiceProvider.overrideWithValue(analytics),
          crashlyticsServiceProvider.overrideWithValue(crashlytics),
          routerProvider.overrideWithValue(
            GoRouter(
              navigatorKey: rootNavigatorKey,
              routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
            ),
          ),
          connectivityStatusProvider.overrideWith((ref) => Stream.value(true)),
          currencyConversionServiceProvider.overrideWithValue(null),
          allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          allCashFlowsStreamProvider.overrideWith((ref) => Stream.value([])),
          legacyCurrencyBackfillServiceProvider.overrideWithValue(
            LegacyCurrencyBackfillService(
              firestore: firestore,
              userId: firestore.uid,
              prefs: prefs,
            ),
          ),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => analytics.setUserId(null)).called(1);
    verify(() => crashlytics.clearUserIdentifier()).called(1);
  });
}
