import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/currency_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';

class _SavedCashFlow {
  _SavedCashFlow(this.amount, this.currency);
  final double amount;
  final String? currency;
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
    saved.add(_SavedCashFlow(amount, currency));
  }
}

/// Also records edits, so a test can tell an edit was saved.
class _RecordingEditNotifier extends _RecordingInvestmentNotifier {
  _RecordingEditNotifier(super.saved);

  @override
  Future<void> updateCashFlow({
    required String id,
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    required DateTime createdAt,
    String? currency,
  }) async {
    saved.add(_SavedCashFlow(amount, currency));
  }
}

void main() {
  // A42: INCOME (an interest payout) is as much a success moment as a
  // RETURN, and is far more common for FD, bond and P2P users, so it now
  // earns the one-shot prompt too. This replaces the earlier test that
  // pinned INCOME as never a success moment.
  group('isReviewPromptSuccessMoment', () {
    for (final type in [CashFlowType.returnFlow, CashFlowType.income]) {
      test('a new (non-editing) $type is a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: false, type: type),
          isTrue,
        );
      });

      test('editing an existing $type is not a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: true, type: type),
          isFalse,
        );
      });
    }

    for (final type in [CashFlowType.invest, CashFlowType.fee]) {
      test('a new $type is never a success moment', () {
        expect(
          isReviewPromptSuccessMoment(isEditing: false, type: type),
          isFalse,
        );
      });
    }
  });

  group('AddTransactionScreen currency', () {
    final usdInvestment = InvestmentEntity(
      id: 'inv-usd',
      name: 'US Treasury',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: 'USD',
    );

    Future<void> pumpScreen(WidgetTester tester) async {
      // Tall enough that the whole form (selector and preview) is built.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The user's base currency is INR; the investment is in USD.
            currencyCodeProvider.overrideWithValue('INR'),
            investmentByIdProvider(
              'inv-usd',
            ).overrideWith((ref) async => usdInvestment),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTransactionScreen(investmentId: 'inv-usd'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? amountPrefix(WidgetTester tester) => tester
        .widgetList<AppTextField>(find.byType(AppTextField))
        .firstWhere((f) => f.label == 'Amount')
        .prefixText;

    testWidgets('a USD investment starts with USD selected and a \$ prefix', (
      tester,
    ) async {
      await pumpScreen(tester);

      final selector = tester.widget<CurrencySelector>(
        find.byType(CurrencySelector),
      );
      expect(selector.selectedCurrency, 'USD');
      expect(amountPrefix(tester), '\$');
    });

    testWidgets('the preview shows the amount in the investment currency', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount').first,
        '1000',
      );
      await tester.pumpAndSettle();

      expect(find.text('-\$1,000.00'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });
  });

  // The preview must show what will be stored: the amount rounded to the
  // currency's minor unit (JPY none, INR two), not always two decimals.
  group('AddTransactionScreen preview precision', () {
    InvestmentEntity investment(String id, String currency) => InvestmentEntity(
      id: id,
      name: 'Deal $currency',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: currency,
    );

    Future<void> enterAmount(
      WidgetTester tester, {
      required String currency,
      required String text,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final id = 'inv-$currency';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            investmentByIdProvider(
              id,
            ).overrideWith((ref) async => investment(id, currency)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTransactionScreen(investmentId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount').first,
        text,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a JPY amount previews as whole yen', (tester) async {
      await enterAmount(tester, currency: 'JPY', text: '125.6');

      expect(find.text('-¥126'), findsOneWidget);
      expect(find.text('-¥125.60'), findsNothing);
    });

    testWidgets('an INR amount previews rounded half away from zero', (
      tester,
    ) async {
      await enterAmount(tester, currency: 'INR', text: '1.005');

      expect(find.text('-₹1.01'), findsOneWidget);
    });
  });

  // The amount field must refuse an amount that rounds to zero in the
  // selected currency, with a specific message, instead of letting the save
  // fail with the generic "Failed to add transaction".
  group('AddTransactionScreen amount that rounds to zero', () {
    InvestmentEntity investment(String currency) => InvestmentEntity(
      id: 'inv-$currency',
      name: 'Deal $currency',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: currency,
    );

    Future<void> saveAmount(
      WidgetTester tester, {
      required String currency,
      required String text,
      required List<_SavedCashFlow> saved,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final id = 'inv-$currency';
      final router = GoRouter(
        initialLocation: '/add',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/add',
            builder: (_, _) => AddTransactionScreen(investmentId: id),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            investmentByIdProvider(
              id,
            ).overrideWith((ref) async => investment(currency)),
            investmentNotifierProvider.overrideWith(
              () => _RecordingInvestmentNotifier(saved),
            ),
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
        text,
      );
      await tester.tap(find.text('Save Cash Flow'));
      await tester.pumpAndSettle();
    }

    testWidgets('JPY 0.4 shows the specific message and saves nothing', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(tester, currency: 'JPY', text: '0.4', saved: saved);

      expect(
        find.text('This amount rounds to zero in JPY. Enter a larger amount.'),
        findsOneWidget,
      );
      expect(find.text('Failed to add transaction'), findsNothing);
      expect(saved, isEmpty);
    });

    testWidgets('JPY 0.5 rounds up to one yen and is saved', (tester) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(tester, currency: 'JPY', text: '0.5', saved: saved);

      expect(find.textContaining('rounds to zero'), findsNothing);
      expect(saved, hasLength(1));
      expect(saved.single.currency, 'JPY');
    });

    testWidgets('INR 0.004 rounds to zero paise and saves nothing', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(tester, currency: 'INR', text: '0.004', saved: saved);

      expect(
        find.text('This amount rounds to zero in INR. Enter a larger amount.'),
        findsOneWidget,
      );
      expect(saved, isEmpty);
    });

    // 15 digits is the most an amount may have (invtrack_rules 19.1). The form
    // says so, instead of letting the notifier refuse with the generic
    // "Failed to add transaction".
    for (final text in ['1000000000000000', '99999999999999999999']) {
      testWidgets('$text is refused with a specific message', (tester) async {
        final saved = <_SavedCashFlow>[];

        await saveAmount(tester, currency: 'INR', text: text, saved: saved);

        expect(find.text('That amount is too large'), findsOneWidget);
        expect(find.text('Failed to add transaction'), findsNothing);
        expect(saved, isEmpty);
      });
    }

    testWidgets('an amount that rounds up to 16 digits is refused', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(
        tester,
        currency: 'JPY',
        text: '999999999999999.5',
        saved: saved,
      );

      expect(find.text('That amount is too large'), findsOneWidget);
      expect(saved, isEmpty);
    });

    testWidgets('the largest 15-digit amount is saved', (tester) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(
        tester,
        currency: 'INR',
        text: '999999999999999',
        saved: saved,
      );

      expect(find.text('That amount is too large'), findsNothing);
      expect(saved, hasLength(1));
    });

    testWidgets('a zero amount keeps the "Must be positive" message', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];

      await saveAmount(tester, currency: 'JPY', text: '0', saved: saved);

      expect(find.text('Must be positive'), findsOneWidget);
      expect(find.textContaining('rounds to zero'), findsNothing);
      expect(saved, isEmpty);
    });
  });

  // Editing prefills the amount in the currency's own precision, so a whole
  // yen is not shown as "126.00", and a blank stored currency never crashes
  // the screen: display falls back to the base currency, saving still fails.
  group('AddTransactionScreen edit prefill', () {
    CashFlowEntity flow(double amount, String currency) => CashFlowEntity(
      id: 'cf-1',
      investmentId: 'inv-1',
      type: CashFlowType.invest,
      amount: amount,
      date: DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 15),
      currency: currency,
    );

    Future<void> pumpEdit(
      WidgetTester tester,
      CashFlowEntity cashFlow, {
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            ...overrides,
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddTransactionScreen(
              investmentId: 'inv-1',
              cashFlowToEdit: cashFlow,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String amountText(WidgetTester tester) => tester
        .widget<TextField>(find.widgetWithText(TextField, 'Amount').first)
        .controller!
        .text;

    testWidgets('a JPY 126 flow prefills as 126', (tester) async {
      await pumpEdit(tester, flow(126, 'JPY'));

      expect(amountText(tester), '126');
    });

    testWidgets('a USD flow still prefills with two decimals', (tester) async {
      await pumpEdit(tester, flow(1000.5, 'USD'));

      expect(amountText(tester), '1000.50');
    });

    testWidgets('a KWD flow prefills with three decimals', (tester) async {
      await pumpEdit(tester, flow(1.235, 'KWD'));

      expect(amountText(tester), '1.235');
    });

    testWidgets(
      'a blank stored currency previews in the base currency without crashing',
      (tester) async {
        await pumpEdit(tester, flow(500, ''));

        expect(tester.takeException(), isNull);
        expect(amountText(tester), '500.00');
        expect(find.text('-₹500.00'), findsOneWidget);
      },
    );

    testWidgets('saving a blank stored currency fails visibly, nothing is '
        'overwritten', (tester) async {
      final repo = FakeInvestmentRepository();
      final stored = flow(500, '');
      await repo.addCashFlow(stored);
      await pumpEdit(
        tester,
        stored,
        overrides: [
          investmentRepositoryProvider.overrideWithValue(repo),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          isAuthenticatedProvider.overrideWithValue(true),
        ],
      );

      await tester.tap(find.text('Save Cash Flow'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Failed to update transaction'), findsOneWidget);
      expect(repo.cashFlows.single.currency, '');
      expect(repo.cashFlows.single.amount, 500);
    });
  });
  // #919: a reminder tapped from cached data can open Add Cash Flow for an
  // investment that was closed on another device. Once the live status says
  // closed, the screen must say so and refuse to add new income.
  group('AddTransactionScreen closed investment', () {
    const closedMessage = 'This investment is closed';

    InvestmentEntity investment(
      InvestmentStatus status, {
      String id = 'inv-fd',
    }) => InvestmentEntity(
      id: id,
      name: 'Bank FD',
      type: InvestmentType.fixedDeposit,
      status: status,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      currency: 'INR',
    );

    final existingCashFlow = CashFlowEntity(
      id: 'cf-1',
      investmentId: 'inv-fd',
      type: CashFlowType.income,
      amount: 1500.50,
      currency: 'INR',
      date: DateTime(2026, 5, 1),
      createdAt: DateTime(2026, 5, 1),
    );

    Future<void> pump(
      WidgetTester tester, {
      required Stream<List<InvestmentEntity>> investments,
      required List<_SavedCashFlow> saved,
      CashFlowEntity? cashFlowToEdit,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/add',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/add',
            builder: (_, _) => AddTransactionScreen(
              investmentId: 'inv-fd',
              initialType: CashFlowType.income,
              cashFlowToEdit: cashFlowToEdit,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            isAuthenticatedProvider.overrideWithValue(true),
            allInvestmentsProvider.overrideWith((ref) => investments),
            investmentByIdProvider(
              'inv-fd',
            ).overrideWith((ref) async => investment(InvestmentStatus.open)),
            investmentNotifierProvider.overrideWith(
              () => _RecordingEditNotifier(saved),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder saveButton() =>
        find.widgetWithText(ElevatedButton, 'Save Cash Flow');

    bool saveEnabled(WidgetTester tester) =>
        tester.widget<ElevatedButton>(saveButton()).onPressed != null;

    Future<void> enterAmount(WidgetTester tester, String text) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount').first,
        text,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an open investment still saves new income', (tester) async {
      final saved = <_SavedCashFlow>[];
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      await pump(tester, investments: investments.stream, saved: saved);
      investments.add([investment(InvestmentStatus.open)]);
      await tester.pumpAndSettle();

      expect(find.text(closedMessage), findsNothing);
      expect(saveEnabled(tester), isTrue);

      await enterAmount(tester, '1500.50');
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.amount, 1500.50);
      expect(saved.single.currency, 'INR');
    });

    testWidgets('an unknown status (nothing emitted yet) does not block', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      await pump(tester, investments: investments.stream, saved: saved);

      expect(find.text(closedMessage), findsNothing);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('closing the investment while the form is open blocks saving', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      await pump(tester, investments: investments.stream, saved: saved);
      investments.add([investment(InvestmentStatus.open)]);
      await tester.pumpAndSettle();
      await enterAmount(tester, '1500.50');
      expect(saveEnabled(tester), isTrue);

      // The server snapshot arrives and says the investment was closed.
      investments.add([investment(InvestmentStatus.closed)]);
      await tester.pumpAndSettle();

      expect(find.text(closedMessage), findsOneWidget);
      expect(find.bySemanticsLabel(closedMessage), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await tester.tap(saveButton(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    testWidgets('an investment that is already closed shows the message', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      await pump(
        tester,
        investments: Stream.value([investment(InvestmentStatus.closed)]),
        saved: saved,
      );

      expect(find.text(closedMessage), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('reopening the investment unblocks saving', (tester) async {
      final saved = <_SavedCashFlow>[];
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      await pump(tester, investments: investments.stream, saved: saved);
      investments.add([investment(InvestmentStatus.closed)]);
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isFalse);

      investments.add([investment(InvestmentStatus.open)]);
      await tester.pumpAndSettle();

      expect(find.text(closedMessage), findsNothing);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a save started from a stale tap handler is refused', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      await pump(tester, investments: investments.stream, saved: saved);
      investments.add([investment(InvestmentStatus.open)]);
      await tester.pumpAndSettle();
      await enterAmount(tester, '1500.50');
      final staleOnPressed = tester
          .widget<ElevatedButton>(saveButton())
          .onPressed!;

      investments.add([investment(InvestmentStatus.closed)]);
      await tester.pumpAndSettle();
      staleOnPressed();
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });

    testWidgets('another investment being closed does not block this one', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      await pump(
        tester,
        investments: Stream.value([
          investment(InvestmentStatus.closed, id: 'inv-other'),
          investment(InvestmentStatus.open),
        ]),
        saved: saved,
      );

      expect(find.text(closedMessage), findsNothing);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('another investment being open does not hide this one closed', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      await pump(
        tester,
        investments: Stream.value([
          investment(InvestmentStatus.open, id: 'inv-other'),
          investment(InvestmentStatus.closed),
        ]),
        saved: saved,
      );

      expect(find.text(closedMessage), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('the closed message is announced as a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        investments: Stream.value([investment(InvestmentStatus.closed)]),
        saved: <_SavedCashFlow>[],
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel(closedMessage)),
        matchesSemantics(label: closedMessage, isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('editing an existing cash flow stays allowed when closed', (
      tester,
    ) async {
      final saved = <_SavedCashFlow>[];
      await pump(
        tester,
        investments: Stream.value([investment(InvestmentStatus.closed)]),
        saved: saved,
        cashFlowToEdit: existingCashFlow,
      );

      expect(find.text(closedMessage), findsNothing);
      expect(saveEnabled(tester), isTrue);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(saved.single.amount, 1500.50);
    });
  });
}
