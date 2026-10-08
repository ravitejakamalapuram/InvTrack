import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/bulk_import/data/services/csv_template_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/import_confirmation_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _CapturingInvestmentNotifier extends InvestmentNotifier {
  _CapturingInvestmentNotifier({this.failure});

  final Object? failure;
  List<InvestmentEntity> investments = [];
  List<CashFlowEntity> cashFlows = [];

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    if (failure != null) throw failure!;
    this.investments = investments;
    this.cashFlows = cashFlows;
    return (investments: investments.length, cashFlows: cashFlows.length);
  }
}

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  // A spreadsheet with no Currency column for the FD, plus one USD row.
  final parseResult = ParsedCsvResult(
    rows: [
      ParsedCashFlowRow(
        rowNumber: 2,
        date: DateTime(2024, 1, 15),
        investmentName: 'HDFC FD',
        type: CashFlowType.invest,
        amount: 100000,
      ),
      ParsedCashFlowRow(
        rowNumber: 3,
        date: DateTime(2024, 6, 15),
        investmentName: 'HDFC FD',
        type: CashFlowType.income,
        amount: 3500,
      ),
      ParsedCashFlowRow(
        rowNumber: 4,
        date: DateTime(2024, 2, 1),
        investmentName: 'US Treasury',
        type: CashFlowType.invest,
        amount: 1000,
        currency: 'USD',
      ),
    ],
    errors: const [],
    totalRows: 3,
    validRows: 3,
  );

  late _CapturingInvestmentNotifier notifier;

  Future<void> pumpScreen(
    WidgetTester tester, {
    ParsedCsvResult? result,
    bool privacy = false,
    Object? failure,
    List<InvestmentEntity> existingInvestments = const [],
    List<CashFlowEntity> existingCashFlows = const [],
    List<InvestmentEntity> archivedInvestments = const [],
    List<CashFlowEntity> archivedCashFlows = const [],
    Stream<List<CashFlowEntity>> Function()? cashFlowStream,
  }) async {
    notifier = _CapturingInvestmentNotifier(failure: failure);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          privacyModeProvider.overrideWith(() => _Privacy(privacy)),
          allInvestmentsProvider.overrideWith(
            (ref) => Stream.value(existingInvestments),
          ),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => cashFlowStream?.call() ?? Stream.value(existingCashFlows),
          ),
          archivedInvestmentsProvider.overrideWith(
            (ref) => Stream.value(archivedInvestments),
          ),
          archivedCashFlowsByInvestmentProvider.overrideWith(
            (ref, id) => Stream.value([
              for (final cf in archivedCashFlows)
                if (cf.investmentId == id) cf,
            ]),
          ),
          investmentNotifierProvider.overrideWith(() => notifier),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImportConfirmationScreen(
            parseResult: result ?? parseResult,
            fileName: 'portfolio.csv',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the resolved currency for every row', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('HDFC FD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Treasury'));
    await tester.pumpAndSettle();

    // Rows with no currency show the base currency, never USD.
    final inrRows = find.widgetWithText(ListTile, 'INR');
    final usdRows = find.widgetWithText(ListTile, 'USD');
    expect(inrRows, findsNWidgets(2));
    expect(usdRows, findsOneWidget);

    // Each row amount is formatted in its own currency.
    expect(
      find.descendant(of: usdRows, matching: find.textContaining('\$')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inrRows, matching: find.textContaining('₹')),
      findsNWidgets(2),
    );
  });

  testWidgets('imports with the resolved currency on flows and investments', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text(_l10n.importAllButton));
    await tester.pumpAndSettle();

    final byName = {for (final i in notifier.investments) i.name: i};
    expect(byName['HDFC FD']!.currency, 'INR');
    expect(byName['US Treasury']!.currency, 'USD');

    final flowCurrencies = {
      for (final cf in notifier.cashFlows) cf.amount: cf.currency,
    };
    expect(flowCurrencies, {100000.0: 'INR', 3500.0: 'INR', 1000.0: 'USD'});
    expect(
      find.text(
        _l10n.importCreatedSummary(
          _l10n.importInvestmentCount(2),
          _l10n.importCashFlowCount(3),
        ),
      ),
      findsOneWidget,
    );
  });

  // ============ A94: privacy mode and localised copy ============
  group('privacy mode (A94)', () {
    final p2p = ParsedCsvResult(
      rows: [
        ParsedCashFlowRow(
          rowNumber: 2,
          date: DateTime(2024, 1, 15),
          investmentName: 'Bhive Investment',
          type: CashFlowType.invest,
          amount: 100000,
          currency: 'INR',
        ),
        ParsedCashFlowRow(
          rowNumber: 3,
          date: DateTime(2025, 1, 15),
          investmentName: 'Bhive Investment',
          type: CashFlowType.returnFlow,
          amount: 112500,
          currency: 'INR',
        ),
      ],
      errors: const [],
      totalRows: 2,
      validRows: 2,
    );
    String inr(double amount) => formatCompactCurrency(
      amount,
      symbol: '₹',
      locale: getCurrencyLocale('INR'),
    );
    Finder labelled(String text) =>
        find.bySemanticsLabel(RegExp(RegExp.escape(text)));

    testWidgets('hides every amount, in text and in semantics', (tester) async {
      // Disposed in finally: Flutter checks for live handles before
      // addTearDown callbacks run, so a teardown would fail every test.
      final semantics = tester.ensureSemantics();
      try {
        await pumpScreen(tester, result: p2p, privacy: true);
        await tester.tap(find.text('Bhive Investment'));
        await tester.pumpAndSettle();

        for (final amount in [inr(100000), inr(112500)]) {
          expect(find.textContaining(amount), findsNothing, reason: amount);
          expect(labelled(amount), findsNothing, reason: amount);
        }
        // The Invested, Income and Returned totals plus the two rows are all
        // masked; a row's semantics merge its texts, so match by substring.
        expect(find.byType(MaskedAmountText), findsNWidgets(5));
        expect(find.bySemanticsLabel(RegExp('Hidden amount')), findsWidgets);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('shows the amounts when privacy mode is off', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpScreen(tester, result: p2p);
        await tester.tap(find.text('Bhive Investment'));
        await tester.pumpAndSettle();

        // Each appears as a total and as its row.
        expect(find.text(inr(100000)), findsNWidgets(2));
        expect(find.text(inr(112500)), findsNWidgets(2));
        expect(labelled(inr(100000)), findsWidgets);
        expect(find.text(_l10n.investedLabel), findsOneWidget);
        expect(find.text(_l10n.importIncomeLabel), findsOneWidget);
        expect(find.text(_l10n.returnedLabel), findsOneWidget);
        expect(find.text(_l10n.importTypeChipInvest), findsOneWidget);
        expect(find.text(_l10n.importTypeChipReturn), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('copy (A94)', () {
    testWidgets('counts use singular and plural forms', (tester) async {
      await pumpScreen(
        tester,
        result: ParsedCsvResult(
          rows: [parseResult.rows.first],
          errors: const ['Row 3: Invalid date: 31/31/2024'],
          totalRows: 2,
          validRows: 1,
        ),
      );

      expect(find.text('1 investment • 1 cash flow'), findsOneWidget);
      expect(find.text('1 cash flow • INR'), findsOneWidget);
      expect(find.text('1 row skipped due to errors'), findsOneWidget);
      expect(find.text(_l10n.importRowsSkipped(1)), findsOneWidget);
    });

    testWidgets('every cash-flow type has its chip', (tester) async {
      ParsedCashFlowRow row(int n, CashFlowType type) => ParsedCashFlowRow(
        rowNumber: n,
        date: DateTime(2024, 1, n),
        investmentName: 'HDFC FD',
        type: type,
        amount: 100,
      );
      await pumpScreen(
        tester,
        result: ParsedCsvResult(
          rows: [
            row(2, CashFlowType.invest),
            row(3, CashFlowType.income),
            row(4, CashFlowType.returnFlow),
            row(5, CashFlowType.fee),
          ],
          errors: const [],
          totalRows: 4,
          validRows: 4,
        ),
      );
      await tester.tap(find.text('HDFC FD'));
      await tester.pumpAndSettle();

      for (final chip in [
        _l10n.importTypeChipInvest,
        _l10n.importTypeChipIncome,
        _l10n.importTypeChipReturn,
        _l10n.importTypeChipFee,
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
    });

    group('when saving fails', () {
      late _MockFirebaseCrashlytics crashlytics;

      setUpAll(() {
        registerFallbackValue(StackTrace.empty);
        registerFallbackValue(const <Object>[]);
      });

      setUp(() {
        crashlytics = _MockFirebaseCrashlytics();
        when(
          () => crashlytics.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
            fatal: any(named: 'fatal'),
            information: any(named: 'information'),
          ),
        ).thenAnswer((_) async {});
        // Tests run with kDebugMode == true, so reporting needs the override.
        CrashlyticsService.enableInDebugMode = true;
        LoggerService.crashlyticsServiceForTesting = CrashlyticsService(
          debugModeEnabled: true,
          crashlytics: crashlytics,
        );
      });

      tearDown(() {
        CrashlyticsService.enableInDebugMode = false;
        LoggerService.crashlyticsServiceForTesting = null;
      });

      testWidgets('shows a fixed message and reports no path or file name', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          failure: Exception('/storage/emulated/0/Download/my_fds.csv'),
        );

        await tester.tap(find.text(_l10n.importAllButton));
        await tester.pumpAndSettle();

        expect(find.text(_l10n.importFailedTryAgain), findsOneWidget);
        expect(find.textContaining('my_fds.csv'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);

        final captured = verify(
          () => crashlytics.recordError(
            captureAny(),
            any(),
            reason: captureAny(named: 'reason'),
            fatal: any(named: 'fatal'),
            information: any(named: 'information'),
          ),
        ).captured;
        expect(captured, hasLength(2));
        for (final value in captured) {
          expect('$value', isNot(contains('my_fds.csv')));
          expect('$value', isNot(contains('/storage')));
        }
      });
    });
  });

  // ============ A25: likely duplicates ============
  group('likely duplicates (A25)', () {
    final template = SimpleCsvParser.parseString(
      CsvTemplateService.generateTemplateContent(),
      baseCurrency: 'INR',
    );
    final created = DateTime(2024, 1, 15, 9);
    final bhive = InvestmentEntity(
      id: 'bhive',
      name: 'Bhive Investment',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: created,
      updatedAt: created,
      currency: 'INR',
    );
    final savedInvest = CashFlowEntity(
      id: 'cf-1',
      investmentId: 'bhive',
      type: CashFlowType.invest,
      amount: 100000,
      currency: 'INR',
      date: DateTime(2024, 1, 15),
      createdAt: created,
    );

    Future<void> pumpTemplate(WidgetTester tester) => pumpScreen(
      tester,
      result: template,
      existingInvestments: [bhive],
      existingCashFlows: [savedInvest],
    );

    bool isSavedInvest(CashFlowEntity cf) =>
        cf.type == CashFlowType.invest &&
        cf.amount == 100000 &&
        cf.date == DateTime(2024, 1, 15);

    testWidgets('re-importing the template warns about the saved row', (
      tester,
    ) async {
      await pumpTemplate(tester);

      expect(find.text(_l10n.importLikelyDuplicates(1)), findsOneWidget);
      expect(find.text(_l10n.importSkipDuplicates), findsOneWidget);

      await tester.tap(find.text('Bhive Investment'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.importDuplicateLabel), findsOneWidget);
    });

    testWidgets('skips the duplicate by default', (tester) async {
      await pumpTemplate(tester);

      await tester.tap(find.text(_l10n.importAllButton));
      await tester.pumpAndSettle();

      expect(notifier.cashFlows, hasLength(template.rows.length - 1));
      expect(notifier.cashFlows.where(isSavedInvest), isEmpty);
    });

    testWidgets('a partial re-import adds the new rows to the existing '
        'investment instead of a second one with the same name', (
      tester,
    ) async {
      await pumpTemplate(tester);
      await tester.tap(find.text('Bhive Investment'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.importAddsToExisting), findsOneWidget);

      await tester.tap(find.text(_l10n.importAllButton));
      await tester.pumpAndSettle();

      final bhiveRows = template.rows
          .where((r) => r.investmentName == 'Bhive Investment')
          .length;
      expect(
        notifier.investments.map((i) => i.name),
        isNot(contains('Bhive Investment')),
      );
      expect(
        notifier.cashFlows.where((cf) => cf.investmentId == 'bhive'),
        hasLength(bhiveRows - 1),
      );
    });

    testWidgets('pauses import when duplicate rows match multiple active investments', (
      tester,
    ) async {
      final first = bhive.copyWith(id: 'bhive-1');
      final second = bhive.copyWith(id: 'bhive-2');
      final result = ParsedCsvResult(
        rows: [
          ParsedCashFlowRow(
            rowNumber: 2,
            date: DateTime(2024, 1, 15),
            investmentName: 'Bhive Investment',
            type: CashFlowType.invest,
            amount: 100000,
            currency: 'INR',
          ),
          ParsedCashFlowRow(
            rowNumber: 3,
            date: DateTime(2024, 2, 15),
            investmentName: 'Bhive Investment',
            type: CashFlowType.invest,
            amount: 200000,
            currency: 'INR',
          ),
        ],
        errors: const [],
        totalRows: 2,
        validRows: 2,
      );
      final firstFlow = savedInvest.copyWith(
        id: 'cf-1',
        investmentId: first.id,
        amount: 100000,
      );
      final secondFlow = savedInvest.copyWith(
        id: 'cf-2',
        investmentId: second.id,
        amount: 200000,
        date: DateTime(2024, 2, 15),
      );

      await pumpScreen(
        tester,
        result: result,
        existingInvestments: [first, second],
        existingCashFlows: [firstFlow, secondFlow],
      );

      expect(find.text(_l10n.importLikelyDuplicates(2)), findsOneWidget);
      expect(find.text(_l10n.importDuplicateCheckFailed), findsOneWidget);
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      expect(notifier.investments, isEmpty);
      expect(notifier.cashFlows, isEmpty);
    });

    testWidgets('the header counts only what Import will write', (
      tester,
    ) async {
      await pumpTemplate(tester);
      final groups = template.rows.map((r) => r.investmentName).toSet();

      // Bhive goes into the existing investment and its saved row is skipped.
      expect(
        find.text(
          _l10n.importCountsSummary(
            _l10n.importInvestmentCount(groups.length - 1),
            _l10n.importCashFlowCount(template.rows.length - 1),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(_l10n.importSkipDuplicates));
      await tester.pumpAndSettle();
      expect(
        find.text(
          _l10n.importCountsSummary(
            _l10n.importInvestmentCount(groups.length - 1),
            _l10n.importCashFlowCount(template.rows.length),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rows matching an archived investment are flagged and '
        'skipped, and the rest become a new investment', (tester) async {
      await pumpScreen(
        tester,
        result: template,
        archivedInvestments: [bhive.copyWith(id: 'archived-bhive')],
        archivedCashFlows: [
          savedInvest.copyWith(investmentId: 'archived-bhive'),
        ],
      );

      expect(find.text(_l10n.importLikelyDuplicates(1)), findsOneWidget);
      await tester.tap(find.text('Bhive Investment'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.importDuplicateArchivedLabel), findsOneWidget);
      expect(find.text(_l10n.importNewBesideArchived), findsOneWidget);

      await tester.tap(find.text(_l10n.importAllButton));
      await tester.pumpAndSettle();

      expect(notifier.cashFlows, hasLength(template.rows.length - 1));
      expect(notifier.cashFlows.where(isSavedInvest), isEmpty);
      expect(
        notifier.cashFlows.where((cf) => cf.investmentId == 'archived-bhive'),
        isEmpty,
      );
      expect(
        notifier.investments.map((i) => i.name),
        contains('Bhive Investment'),
      );
    });

    testWidgets('import stays off until the duplicate check can run', (
      tester,
    ) async {
      var failing = true;
      await pumpScreen(
        tester,
        result: template,
        existingInvestments: [bhive],
        cashFlowStream: () => failing
            ? Stream.error(Exception('permission-denied'))
            : Stream.value([savedInvest]),
      );

      GradientButton button() =>
          tester.widget<GradientButton>(find.byType(GradientButton));
      expect(find.text(_l10n.importDuplicateCheckFailed), findsOneWidget);
      expect(button().onPressed, isNull);

      failing = false;
      await tester.tap(find.text(_l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.importDuplicateCheckFailed), findsNothing);
      expect(button().onPressed, isNotNull);
      expect(find.text(_l10n.importLikelyDuplicates(1)), findsOneWidget);
    });

    testWidgets('a failed archived lookup also pauses import', (tester) async {
      notifier = _CapturingInvestmentNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            privacyModeProvider.overrideWith(() => _Privacy(false)),
            allInvestmentsProvider.overrideWith((ref) => Stream.value([bhive])),
            allCashFlowsStreamProvider.overrideWith(
              (ref) => Stream.value([savedInvest]),
            ),
            archivedInvestmentsProvider.overrideWith(
              (ref) => Stream.error(Exception('unavailable')),
            ),
            investmentNotifierProvider.overrideWith(() => notifier),
            analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ImportConfirmationScreen(
              parseResult: template,
              fileName: 'portfolio.csv',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.importDuplicateCheckFailed), findsOneWidget);
      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
    });

    testWidgets('imports the duplicate when the user turns skipping off', (
      tester,
    ) async {
      await pumpTemplate(tester);

      await tester.tap(find.text(_l10n.importSkipDuplicates));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.importAllButton));
      await tester.pumpAndSettle();

      expect(notifier.cashFlows, hasLength(template.rows.length));
    });

    testWidgets('import waits until existing data has loaded', (tester) async {
      final pending = StreamController<List<CashFlowEntity>>();
      addTearDown(pending.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWithValue('INR'),
            privacyModeProvider.overrideWith(() => _Privacy(false)),
            allInvestmentsProvider.overrideWith((ref) => Stream.value([bhive])),
            allCashFlowsStreamProvider.overrideWith((ref) => pending.stream),
            archivedInvestmentsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            investmentNotifierProvider.overrideWith(
              _CapturingInvestmentNotifier.new,
            ),
            analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ImportConfirmationScreen(
              parseResult: template,
              fileName: 'portfolio.csv',
            ),
          ),
        ),
      );
      await tester.pump();

      GradientButton button() =>
          tester.widget<GradientButton>(find.byType(GradientButton));
      expect(button().onPressed, isNull);

      pending.add([savedInvest]);
      await tester.pumpAndSettle();

      expect(button().onPressed, isNotNull);
      expect(find.text(_l10n.importLikelyDuplicates(1)), findsOneWidget);
    });

    testWidgets('no warning when nothing matches', (tester) async {
      await pumpScreen(tester, result: template);

      expect(find.text(_l10n.importSkipDuplicates), findsNothing);
      expect(find.text(_l10n.importDuplicateLabel), findsNothing);
    });
  });
}
