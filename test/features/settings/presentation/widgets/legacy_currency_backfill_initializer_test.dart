// A113: the start-up question about records without a currency writes to
// Firestore when confirmed. It must not open over the lock screen, where
// whoever holds the phone could answer it without the PIN.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

void main() {
  const title = 'Older records have no currency';
  const message =
      'Some records were saved before the app supported currencies. They are '
      'shown in INR now. If they were entered in INR, mark them so they stay '
      'in INR when you change your currency. If not, choose Not Now and '
      'change your currency in Settings first.';

  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore()
      ..put('cashflows', 'cf-1', {'amount': 10.0});
  });

  LegacyCurrencyBackfillService service() => LegacyCurrencyBackfillService(
    firestore: firestore,
    userId: firestore.uid,
    prefs: prefs,
  );

  Widget app({required bool locked}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      securityProvider.overrideWith(() => _TestSecurity(locked: locked)),
      legacyCurrencyBackfillServiceProvider.overrideWithValue(service()),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
    ),
  );

  _TestSecurity security(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(LegacyCurrencyBackfillInitializer)),
          ).read(securityProvider.notifier)
          as _TestSecurity;

  bool cashFlowStamped() =>
      firestore.stored('cashflows', 'cf-1')!.containsKey('currency');

  testWidgets('locked: not asked over the lock screen; asked once after '
      'unlocking', (tester) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
    expect(find.text('Mark as INR'), findsNothing);
    expect(cashFlowStamped(), isFalse);
    expect(service().confirmedCurrency, isNull);
    expect(service().promptDismissals, 0);

    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.bySemanticsLabel(message), findsOneWidget);

    // Locking and unlocking again does not stack a second question.
    security(tester).lockApp();
    await tester.pumpAndSettle();
    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(cashFlowStamped(), isFalse);
  });

  testWidgets('no PIN: asked at once, as before', (tester) async {
    await tester.pumpWidget(app(locked: false));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text('Mark as INR'));
    await tester.pumpAndSettle();

    expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
  });

  testWidgets('removed while waiting for unlock: stops quietly and asks on '
      'the next start', (tester) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(cashFlowStamped(), isFalse);
    expect(service().promptDismissals, 0);

    await tester.pumpWidget(app(locked: false));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
  });
}

class _TestSecurity extends SecurityNotifier {
  _TestSecurity({required this.locked});

  final bool locked;

  @override
  SecurityState build() => SecurityState(hasPin: locked, isLocked: locked);

  void unlock() => state = state.copyWith(isLocked: false);
}
