// A03-F1: the one-time question about records saved without a currency must
// actually run in the app. Removing LegacyCurrencyBackfillInitializer from
// InvTrackerApp would otherwise pass every other test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/fake_legacy_currency_firestore.dart';

void main() {
  testWidgets('InvTrackerApp mounts the legacy-currency check, which asks '
      'about records without a currency', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final firestore = FakeLegacyCurrencyFirestore()
      ..put('cashflows', 'cf-1', {'amount': 10.0});
    final service = LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(_Unlocked.new),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
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
          legacyCurrencyBackfillServiceProvider.overrideWithValue(service),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LegacyCurrencyBackfillInitializer), findsOneWidget);
    expect(find.text('Older records have no currency'), findsOneWidget);
    expect(find.text('Mark as INR'), findsOneWidget);
  });
}

/// No PIN set. The question waits while the app is locked (A113), and the
/// real notifier reads as locked here, with no secure storage in tests.
class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}
