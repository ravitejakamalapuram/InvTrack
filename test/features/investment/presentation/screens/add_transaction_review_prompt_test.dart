// A42: with the code-default flags, saving a new INCOME or RETURN asks the
// review service for the one-shot Play prompt. The service itself enforces
// "once per install" (see review_prompt_service_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/providers/review_prompt_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/review/review_prompt_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingReviewPromptService implements ReviewPromptService {
  int requests = 0;

  @override
  Future<void> maybeRequestAfterExitRecorded() async => requests++;
}

class _SavedCashFlow {
  _SavedCashFlow(this.type, this.amount);
  final CashFlowType type;
  final double amount;
}

class _RecordingInvestmentNotifier extends InvestmentNotifier {
  _RecordingInvestmentNotifier(this.saved);
  final List<_SavedCashFlow> saved;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<void> addCashFlow({
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    String? currency,
  }) async {
    saved.add(_SavedCashFlow(type, amount));
  }
}

final _fd = InvestmentEntity(
  id: 'fd-1',
  name: 'Bank FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  currency: 'INR',
);

Future<void> _saveNew(
  WidgetTester tester, {
  required CashFlowType type,
  required _CountingReviewPromptService review,
  required List<_SavedCashFlow> saved,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/add',
        builder: (_, _) =>
            AddTransactionScreen(investmentId: 'fd-1', initialType: type),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWithValue('INR'),
        investmentByIdProvider('fd-1').overrideWith((ref) async => _fd),
        investmentNotifierProvider.overrideWith(
          () => _RecordingInvestmentNotifier(saved),
        ),
        reviewPromptServiceProvider.overrideWithValue(review),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextField, 'Amount').first,
    '18750',
  );
  await tester.tap(find.text('Save Cash Flow'));
  // The prompt is scheduled one second after the save.
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  for (final type in [CashFlowType.income, CashFlowType.returnFlow]) {
    testWidgets('saving a new $type asks for the review prompt once', (
      tester,
    ) async {
      final review = _CountingReviewPromptService();
      final saved = <_SavedCashFlow>[];

      await _saveNew(tester, type: type, review: review, saved: saved);

      expect(saved, hasLength(1));
      expect(saved.single.type, type);
      expect(saved.single.amount, 18750.00);
      expect(review.requests, 1);
    });
  }

  for (final type in [CashFlowType.invest, CashFlowType.fee]) {
    testWidgets('saving a new $type does not ask for the review prompt', (
      tester,
    ) async {
      final review = _CountingReviewPromptService();
      final saved = <_SavedCashFlow>[];

      await _saveNew(tester, type: type, review: review, saved: saved);

      expect(saved, hasLength(1));
      expect(review.requests, 0);
    });
  }
}
