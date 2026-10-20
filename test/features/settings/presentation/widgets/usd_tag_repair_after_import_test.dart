// A110: after the US dollar question was answered, a restore or import that
// writes USD tags again leads to the question. What the user kept is not
// asked about twice, and untouched documents are not scanned.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/usd_tag_repair_check_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_prompt.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';
import '../../../../mocks/mock_analytics_service.dart';

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;

  const title = 'Investments recorded in US dollars';

  void putInvestment(String id, String currency) {
    firestore
      ..put('investments', id, {'name': 'Inv $id', 'currency': currency})
      ..put('cashflows', 'cf-$id', {
        'investmentId': id,
        'type': 'INVEST',
        'amount': 1000.0,
        'currency': currency,
      });
  }

  UsdTagRepairService service() => UsdTagRepairService(
    firestore: firestore,
    userId: firestore.uid,
    prefs: prefs,
  );

  Widget app({bool holder = false}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      securityProvider.overrideWith(_Unlocked.new),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      if (holder)
        usdTagRepairServiceProvider.overrideWith((ref) => ref.watch(_holder))
      else
        usdTagRepairServiceProvider.overrideWithValue(service()),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: UsdTagRepairInitializer(child: SizedBox())),
    ),
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SizedBox).first));

  void restored(WidgetTester tester, Set<String> investmentIds) =>
      container(tester)
          .read(usdTagRepairPendingCheckProvider.notifier)
          .reportImport(
            ZipImportResult(
              investmentsImported: investmentIds.length,
              cashflowsImported: investmentIds.length,
              goalsImported: 0,
              documentsImported: 0,
              importedInvestmentIds: investmentIds,
            ),
          );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore();
    // The question was answered before this session (base currency INR).
    await service().markResolved();
  });

  testWidgets('a restored all-USD investment is asked about again', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);

    putInvestment('x', 'USD');
    restored(tester, {'x'});
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.text('Inv x'), findsOneWidget);
  });

  testWidgets('one kept as USD earlier (same id) is not asked about again', (
    tester,
  ) async {
    await service().markKept(['x']);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    putInvestment('x', 'USD');
    restored(tester, {'x'});
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
  });

  testWidgets('Keep is remembered by id, and USD documents the restore did '
      'not write are not listed', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    putInvestment('x', 'USD');
    putInvestment('older', 'USD');
    restored(tester, {'x'});
    await tester.pumpAndSettle();
    expect(find.text('Inv older'), findsNothing);

    await tester.tap(find.text('Keep in US dollars'));
    await tester.pumpAndSettle();
    expect(service().keptIds, {'x'});

    restored(tester, {'x'});
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('a restore that is all INR asks nothing', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    putInvestment('x', 'INR');
    restored(tester, {'x'});
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
  });

  testWidgets('the check cannot finish (offline): the ids wait and are asked '
      'about at the next report', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    putInvestment('x', 'USD');
    firestore.readError = Exception('offline');
    restored(tester, {'x'});
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);

    firestore.readError = null;
    putInvestment('other', 'INR');
    restored(tester, {'other'});
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.text('Inv x'), findsOneWidget);
  });

  testWidgets('the account question is still open: the ids wait instead of '
      'being dropped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore();
    putInvestment('x', 'USD');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // The start-up question is open over the screen.
    expect(find.text(title), findsOneWidget);

    restored(tester, {'x'});
    await tester.pumpAndSettle();

    expect(container(tester).read(usdTagRepairPendingCheckProvider), {'x'});
  });

  testWidgets('ids that waited for the account question are asked about once '
      'it is answered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore();
    putInvestment('x', 'USD');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    putInvestment('z', 'USD');
    restored(tester, {'z'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep in US dollars'));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.text('Inv z'), findsOneWidget);
    expect(find.text('Inv x'), findsNothing);
  });

  testWidgets('ids still waiting when the user signs out are dropped', (
    tester,
  ) async {
    await tester.pumpWidget(app(holder: true));
    final c = container(tester);
    c.read(_holder.notifier).set(service());
    await tester.pumpAndSettle();
    putInvestment('x', 'USD');
    firestore.readError = Exception('offline');
    restored(tester, {'x'});
    await tester.pumpAndSettle();
    expect(c.read(usdTagRepairPendingCheckProvider), {'x'});

    c.read(_holder.notifier).set(null);
    await tester.pumpAndSettle();

    expect(c.read(usdTagRepairPendingCheckProvider), isEmpty);
  });
}

final _holder = NotifierProvider<_Holder, UsdTagRepairService?>(_Holder.new);

class _Holder extends Notifier<UsdTagRepairService?> {
  @override
  UsdTagRepairService? build() => null;

  void set(UsdTagRepairService? service) => state = service;
}

class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(hasPin: false, isLocked: false);
}
