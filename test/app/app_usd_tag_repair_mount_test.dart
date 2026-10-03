// A04: the one-time question about investments wrongly stored as US dollars
// must actually run in the app. Removing UsdTagRepairInitializer from
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
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/fake_legacy_currency_firestore.dart';

void main() {
  testWidgets('InvTrackerApp mounts the US dollar check, which asks about '
      'investments stored as US dollars', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final firestore = FakeLegacyCurrencyFirestore()
      ..put('investments', 'inv-1', {'name': 'FD', 'currency': 'USD'})
      ..put('cashflows', 'cf-1', {
        'investmentId': 'inv-1',
        'amount': 10.0,
        'currency': 'USD',
      });
    // A real currency check for records without a currency, as in the app:
    // on the first start after the update it has not finished yet.
    final legacy = LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );
    final service = UsdTagRepairService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
          legacyCurrencyBackfillServiceProvider.overrideWithValue(legacy),
          usdTagRepairServiceProvider.overrideWithValue(service),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UsdTagRepairInitializer), findsOneWidget);
    expect(find.text('Investments recorded in US dollars'), findsOneWidget);
    expect(find.text('Change to INR'), findsOneWidget);
  });
}
