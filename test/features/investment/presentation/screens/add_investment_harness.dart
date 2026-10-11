// Shared setup for the add investment form tests: a notifier that records what
// the form sends instead of saving, and a pump that builds the screen under a
// GoRouter with a stub investment detail route.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

/// What one call of `addInvestment` received.
class AddCall {
  const AddCall({
    required this.name,
    required this.type,
    required this.notes,
    required this.maturityDate,
    required this.incomeFrequency,
    required this.startDate,
    required this.expectedRate,
    required this.tenureMonths,
    required this.platform,
    required this.interestPayoutMode,
    required this.autoRenewal,
    required this.riskLevel,
    required this.compoundingFrequency,
    required this.currency,
    required this.customTypeLabel,
    required this.id,
    required this.initialAmount,
    required this.reportsWriteResult,
  });

  final String name;
  final InvestmentType type;
  final String? notes;
  final DateTime? maturityDate;
  final IncomeFrequency? incomeFrequency;
  final DateTime? startDate;
  final double? expectedRate;
  final int? tenureMonths;
  final String? platform;
  final InterestPayoutMode? interestPayoutMode;
  final bool? autoRenewal;
  final RiskLevel? riskLevel;
  final CompoundingFrequency? compoundingFrequency;
  final String? currency;
  final String? customTypeLabel;
  final String? id;
  final double? initialAmount;

  /// The form passed an `onWriteResult` callback.
  final bool reportsWriteResult;
}

/// Records every `addInvestment` and `updateInvestment` call. Behaviour is set
/// by the test: fail the first [failures] adds, report [confirmed] through
/// `onWriteResult`, or hold every add open until [gate] completes.
class RecordingInvestmentNotifier extends InvestmentNotifier {
  RecordingInvestmentNotifier(this.adds, this.updates);

  final List<AddCall> adds;
  final List<Map<String, Object?>> updates;
  int failures = 0;
  bool? confirmed;
  Completer<void>? gate;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<InvestmentEntity> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
    String? customTypeLabel,
    String? id,
    double? initialAmount,
    void Function(bool confirmed)? onWriteResult,
  }) async {
    adds.add(
      AddCall(
        name: name,
        type: type,
        notes: notes,
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        startDate: startDate,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
        interestPayoutMode: interestPayoutMode,
        autoRenewal: autoRenewal,
        riskLevel: riskLevel,
        compoundingFrequency: compoundingFrequency,
        currency: currency,
        customTypeLabel: customTypeLabel,
        id: id,
        initialAmount: initialAmount,
        reportsWriteResult: onWriteResult != null,
      ),
    );
    final hold = gate;
    if (hold != null) await hold.future;
    if (failures > 0) {
      failures--;
      throw StateError('the write failed');
    }
    final report = confirmed;
    if (report != null) onWriteResult?.call(report);
    return InvestmentEntity(
      id: id ?? 'generated-id',
      name: name,
      type: type,
      status: InvestmentStatus.open,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: currency ?? 'INR',
      startDate: startDate,
    );
  }

  @override
  Future<void> updateInvestment({
    required String id,
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
    String? customTypeLabel,
  }) async {
    updates.add({'id': id, 'name': name, 'startDate': startDate});
  }
}

/// How the add screen is opened, as in the app or as a GoRouter route.
enum Opener {
  /// `Navigator.push(MaterialPageRoute)` from a page, as every button of the
  /// app does. GoRouter does not know about the route.
  navigatorPush,

  /// A GoRoute above the opener.
  goRoute,
}

/// A running form: what it sent, and where it navigated.
class FormHarness {
  FormHarness({
    required this.adds,
    required this.updates,
    required this.notifier,
    required this.analytics,
    required this.router,
    required this.detailVisits,
    required this.navigatorKey,
  });

  final List<AddCall> adds;
  final List<Map<String, Object?>> updates;
  final RecordingInvestmentNotifier notifier;
  final FakeAnalyticsService analytics;
  final GoRouter router;
  final GlobalKey<NavigatorState> navigatorKey;

  /// The stub `/investments/:id` route, one entry for each time it was built.
  final List<({String id, Object? extra})> detailVisits;
}

const _pageKey = ValueKey('opener-page');

/// Pumps the add screen opened from a page. The opener page shows the text
/// 'Opener'; tapping the screen's close button must come back to it.
Future<FormHarness> pumpAddForm(
  WidgetTester tester, {
  bool flagOn = false,
  bool privacy = false,
  String baseCurrency = 'INR',
  DateTime? now,
  Size size = const Size(411, 842),
  double devicePixelRatio = 1.0,
  double textScale = 1.0,
  Opener opener = Opener.navigatorPush,
  InvestmentTemplate? template,
  InvestmentEntity? edit,
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  final adds = <AddCall>[];
  final updates = <Map<String, Object?>>[];
  final detailVisits = <({String id, Object? extra})>[];
  final notifier = RecordingInvestmentNotifier(adds, updates);
  final analytics = FakeAnalyticsService();
  final rootKey = GlobalKey<NavigatorState>();

  Widget form() => AddInvestmentScreen(
    investmentToEdit: edit,
    preselectedTemplate: template,
  );

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          key: _pageKey,
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('Opener'),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => form()),
                  ),
                  child: const Text('Open form'),
                ),
              ],
            ),
          ),
        ),
        routes: [GoRoute(path: 'add', builder: (_, _) => form())],
      ),
      GoRoute(
        path: '/investments/:id',
        builder: (context, state) {
          detailVisits.add((
            id: state.pathParameters['id']!,
            extra: state.extra,
          ));
          return Scaffold(body: Text('Detail ${state.pathParameters['id']}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWithValue(baseCurrency),
        analyticsServiceProvider.overrideWithValue(analytics),
        isAuthenticatedProvider.overrideWithValue(true),
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(false),
        firstInvestmentFormEnabledProvider.overrideWithValue(flagOn),
        isPrivacyModeActiveProvider.overrideWithValue(privacy),
        if (now != null) valuationClockProvider.overrideWithValue(() => now),
        investmentNotifierProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (opener == Opener.goRoute) {
    router.push('/add');
  } else {
    await tester.tap(find.text('Open form'));
  }
  if (settle) await tester.pumpAndSettle();

  return FormHarness(
    adds: adds,
    updates: updates,
    notifier: notifier,
    analytics: analytics,
    router: router,
    detailVisits: detailVisits,
    navigatorKey: rootKey,
  );
}

/// The text field inside the widget with [key].
Finder fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextFormField));

Finder nameField() => fieldIn(AddInvestmentKeys.name);
