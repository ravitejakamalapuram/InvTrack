// A40 (#783) PR-2: the add investment form behind FeatureFlag.firstInvestmentFlow.
// Type chips, a name, an optional amount invested, a start date that defaults
// to today and dates the first cash flow, and everything else behind "More
// details". The notifier is recorded, never run: what matters here is what the
// form sends it, and what the user sees and where they land.
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/currency_selector.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/more_details_tile.dart';
import 'package:inv_tracker/core/widgets/sticky_form_action.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/start_date_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

import '../../../../helpers/inter_font.dart';
import 'add_investment_harness.dart';

/// 14:30 on the day the tests run: the form's "today" is Oct 11, 2026, and what
/// it saves must be that day at 00:00, not 14:30.
final _now = DateTime(2026, 10, 11, 14, 30);
final _today = DateTime(2026, 10, 11);

const _helperToday = 'Today. Also the date of your first cash flow.';
const _helperOther = 'Also the date of your first cash flow.';
const _failed = 'Could not add this investment. Nothing was saved. Try again.';
const _offline = 'Saved on this device. Syncs when you are online.';
const _created = 'Investment created successfully';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

/// The English strings with the ones the form's own labels use replaced by
/// marks, so a test can tell text from the strings from a literal in the code.
class _MarkedStrings extends AppLocalizationsEn {
  @override
  String get investmentNameLabel => 'NAME-L';
  @override
  String get investmentNameHint => 'NAME-H';
  @override
  String get investmentCurrencyLabel => 'CURRENCY-L';
  @override
  String get investmentCurrencySubtitle => 'CURRENCY-S';
  @override
  String get investmentNotesLabel => 'NOTES-L';
  @override
  String get investmentNotesHint => 'NOTES-H';
}

class _MarkedDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _MarkedDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) async => _MarkedStrings();
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

Finder _chip(InvestmentType type) =>
    find.byKey(AddInvestmentKeys.typeChip(type));

Finder _submit() => find.byKey(AddInvestmentKeys.submit);

Finder _amountField() => fieldIn(AddInvestmentKeys.amount);

Future<FormHarness> _open(
  WidgetTester tester, {
  bool privacy = false,
  String baseCurrency = 'INR',
  Opener opener = Opener.navigatorPush,
  InvestmentTemplate? template,
}) => pumpAddForm(
  tester,
  flagOn: true,
  now: _now,
  privacy: privacy,
  baseCurrency: baseCurrency,
  opener: opener,
  template: template,
);

Future<void> _tapChip(WidgetTester tester, InvestmentType type) async {
  await tester.ensureVisible(_chip(type));
  await tester.pumpAndSettle();
  await tester.tap(_chip(type));
  await tester.pumpAndSettle();
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(AddInvestmentKeys.moreDetails));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More details'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String? name, String? amount}) async {
  if (name != null) await tester.enterText(nameField(), name);
  if (amount != null) await tester.enterText(_amountField(), amount);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(_submit());
  await tester.pumpAndSettle();
}

Finder _fieldLabelled(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(EditableText),
);

/// What the text field behind [field] (the field, or its editable) holds.
String _text(WidgetTester tester, Finder field) {
  final editable = tester.widget(field) is EditableText
      ? field
      : find.descendant(of: field, matching: find.byType(EditableText));
  return tester.widget<EditableText>(editable).controller.text;
}

void main() {
  setUpAll(loadInterFont);

  group('the form', () {
    testWidgets('14 type chips in one scrolling row; no Quick Start or grid', (
      tester,
    ) async {
      await _open(tester);

      final selector = tester.widget<TypeSelector<InvestmentType>>(
        find.byType(TypeSelector<InvestmentType>),
      );
      expect(selector.scrollingRow, isTrue);
      expect(selector.gridLayout, isFalse);
      expect(selector.selectedValue, InvestmentType.p2pLending);
      for (final type in InvestmentType.values) {
        expect(_chip(type), findsOneWidget, reason: type.name);
      }
      expect(InvestmentType.values, hasLength(14));
      expect(find.text('⚡ Quick Start'), findsNothing);
      expect(find.text('Start Date (Optional)'), findsNothing);
    });

    testWidgets('the name, currency and notes texts come from the strings', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAddForm(
        tester,
        flagOn: true,
        now: _now,
        l10nDelegate: const _MarkedDelegate(),
      );

      expect(find.text('NAME-L'), findsWidgets);
      expect(find.text('NAME-H'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('NAME-L')), findsWidgets);
      expect(find.text('Investment Name'), findsNothing);

      await _openMore(tester);
      expect(find.text('CURRENCY-L'), findsOneWidget);
      expect(find.text('CURRENCY-S'), findsOneWidget);
      expect(find.text('NOTES-L'), findsWidgets);
      expect(find.text('NOTES-H'), findsOneWidget);
      expect(find.text('Investment Currency'), findsNothing);
      expect(find.text('Notes (Optional)'), findsNothing);
      handle.dispose();
    });

    testWidgets('title, type label, name, amount, date, More details, button', (
      tester,
    ) async {
      await _open(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Add Investment'),
        ),
        findsOneWidget,
      );
      expect(find.text('Investment Type'), findsOneWidget);
      expect(find.byKey(AddInvestmentKeys.name), findsOneWidget);
      expect(find.byKey(AddInvestmentKeys.amount), findsOneWidget);
      expect(find.byType(StartDateField), findsOneWidget);
      expect(find.byType(MoreDetailsTile), findsOneWidget);
      expect(find.byType(StickyFormAction), findsOneWidget);
      expect(
        find.descendant(of: _submit(), matching: find.text('Add Investment')),
        findsOneWidget,
      );
      // The rest waits behind More details.
      expect(find.byType(CurrencySelector), findsNothing);
      expect(find.byKey(AddInvestmentKeys.notes), findsNothing);
      expect(find.text('Currency, rate, term, notes and more'), findsOneWidget);
    });

    testWidgets('the amount is named in the base currency', (tester) async {
      await _open(tester);

      final field = tester.widget<AppTextField>(
        find.byKey(AddInvestmentKeys.amount),
      );
      expect(field.label, 'Amount invested in INR');
      expect(field.prefixText, '₹');
      expect(find.text('Optional. You can add it later.'), findsOneWidget);
    });

    testWidgets('close goes back to the page that opened it', (tester) async {
      final harness = await _open(tester);
      final depth = harness.stack.depth;

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AddInvestmentScreen), findsNothing);
      expect(find.text('Opener'), findsOneWidget);
      expect(harness.stack.depth, depth - 1);
      expect(harness.adds, isEmpty);
    });
  });

  group('the start date', () {
    testWidgets('is today, Oct 11, 2026, whatever the time of day', (
      tester,
    ) async {
      await _open(tester);

      expect(
        find.descendant(
          of: find.byType(StartDateField),
          matching: find.text('Oct 11, 2026'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the helper needs an amount that can be saved', (tester) async {
      await _open(tester);

      // These make no first cash flow, so the date is not one.
      for (final typed in ['-5', '0', 'abc']) {
        await _fill(tester, amount: typed);
        expect(
          find.text(_helperToday),
          findsNothing,
          reason: '"$typed" is not an amount',
        );
      }

      await _fill(tester, amount: '50000');
      expect(find.text(_helperToday), findsOneWidget);
    });

    testWidgets('the helper shows once an amount is typed, not before', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text(_helperToday), findsNothing);
      expect(find.text(_helperOther), findsNothing);

      await _fill(tester, amount: '100000');
      expect(find.text(_helperToday), findsOneWidget);

      await _fill(tester, amount: '');
      expect(find.text(_helperToday), findsNothing);
    });

    testWidgets('is saved as 00:00 of that day, not the time it was opened', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      final saved = harness.adds.single.startDate!;
      expect(saved, _today);
      expect(
        [saved.hour, saved.minute, saved.second, saved.millisecond],
        [0, 0, 0, 0],
      );
    });

    testWidgets('a picked day is the one saved, and the helper drops "Today"', (
      tester,
    ) async {
      final harness = await _open(tester);
      await _fill(tester, name: 'Grip FD', amount: '100000');

      await tester.tap(find.byType(StartDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 5, 2026'), findsOneWidget);
      expect(find.text(_helperOther), findsOneWidget);
      expect(find.text(_helperToday), findsNothing);

      await _tapSubmit(tester);
      expect(harness.adds.single.startDate, DateTime(2026, 10, 5));
    });

    testWidgets('a day after today cannot be picked', (tester) async {
      final harness = await _open(tester);
      await _fill(tester, name: 'Grip FD', amount: '100000');

      await tester.tap(find.byType(StartDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 11, 2026'), findsOneWidget);
      await _tapSubmit(tester);
      expect(harness.adds.single.startDate, _today);
    });

    testWidgets('a picked day without a tenure works out no maturity date', (
      tester,
    ) async {
      final harness = await _open(tester);
      await _fill(tester, name: 'Grip FD');

      await tester.tap(find.byType(StartDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _tapSubmit(tester);

      // No tenure, so no maturity date is worked out.
      expect(harness.adds.single.maturityDate, isNull);
    });
  });

  group('what is sent', () {
    for (final (typed, expected) in [
      ('100000', 100000.0),
      ('1,00,000', 100000.0),
      ('1,50,000', 150000.0),
      ('1,50', 1.5),
      ('2500.75', 2500.75),
    ]) {
      testWidgets('name Grip FD with amount "$typed" sends $expected', (
        tester,
      ) async {
        final harness = await _open(tester);

        await _fill(tester, name: 'Grip FD', amount: typed);
        await _tapSubmit(tester);

        final call = harness.adds.single;
        expect(call.name, 'Grip FD');
        expect(call.initialAmount, expected);
        expect(call.type, InvestmentType.p2pLending);
        expect(call.currency, 'INR');
        expect(call.id, isNotNull);
        expect(call.id, isNotEmpty);
        expect(call.reportsWriteResult, isTrue);
      });
    }

    testWidgets('no amount sends null, still with an id and today', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.initialAmount, isNull);
      expect(call.id, isNotEmpty);
      expect(call.startDate, _today);
    });

    testWidgets('an amount of spaces sends null', (tester) async {
      final harness = await _open(tester);

      await _fill(tester, name: 'Grip FD', amount: '   ');
      await _tapSubmit(tester);

      expect(harness.adds.single.initialAmount, isNull);
    });

    testWidgets('the currency is the base currency: GBP, never USD', (
      tester,
    ) async {
      final harness = await _open(tester, baseCurrency: 'GBP');

      expect(
        tester.widget<AppTextField>(find.byKey(AddInvestmentKeys.amount)).label,
        'Amount invested in GBP',
      );
      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(harness.adds.single.currency, 'GBP');
      expect(harness.adds.single.currency, isNot('USD'));
    });

    testWidgets('the typed notes, rate and tenure go with it', (tester) async {
      final harness = await _open(tester);

      await _openMore(tester);
      await tester.enterText(nameField(), 'Grip FD');
      await tester.enterText(
        fieldIn(AddInvestmentKeys.notes),
        '  Senior citizen  ',
      );
      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '7.25',
      );
      await tester.enterText(_fieldLabelled('Tenure (Months)'), '12');
      await tester.pump();
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.notes, 'Senior citizen');
      expect(call.expectedRate, 7.25);
      expect(call.tenureMonths, 12);
      // A typed tenure works out the maturity date from the start date.
      final maturity = call.maturityDate!;
      expect([maturity.year, maturity.month, maturity.day], [2027, 10, 11]);
    });
  });

  group('the estimate card needs an amount (design system rule 9)', () {
    Future<void> typeRateAndTenure(WidgetTester tester) async {
      await _openMore(tester);
      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '7.25',
      );
      await tester.enterText(_fieldLabelled('Tenure (Months)'), '12');
      await tester.pump();
    }

    testWidgets('a rate and a tenure with no amount show no estimate', (
      tester,
    ) async {
      await _open(tester);
      await typeRateAndTenure(tester);

      expect(find.text('Estimated Returns'), findsNothing);
      expect(find.text('Maturity Value'), findsNothing);
    });

    testWidgets('an unreadable or non-positive amount shows no estimate', (
      tester,
    ) async {
      await _open(tester);
      await typeRateAndTenure(tester);

      for (final typed in ['-5', '0', 'abc']) {
        await _fill(tester, amount: typed);
        expect(
          find.text('Estimated Returns'),
          findsNothing,
          reason: '"$typed" is not an amount',
        );
      }
    });

    testWidgets('a typed amount shows the estimate, and clearing it hides it', (
      tester,
    ) async {
      await _open(tester);
      await typeRateAndTenure(tester);

      await _fill(tester, amount: '50000');
      expect(find.text('Estimated Returns'), findsOneWidget);

      await _fill(tester, amount: '');
      expect(find.text('Estimated Returns'), findsNothing);
    });
  });

  group('what is refused', () {
    for (final (typed, message) in [
      ('0', 'Enter an amount above 0'),
      ('0.00', 'Enter an amount above 0'),
      ('-5', 'Enter an amount above 0'),
      (
        '1,5000',
        'Enter a valid amount. Check the commas and the decimal point.',
      ),
      ('1000000000000000', 'That amount is too large'),
    ]) {
      testWidgets('amount "$typed" shows "$message" and sends nothing', (
        tester,
      ) async {
        final harness = await _open(tester);

        await _fill(tester, name: 'Grip FD', amount: typed);
        await _tapSubmit(tester);

        expect(find.text(message), findsOneWidget);
        expect(harness.adds, isEmpty);
        expect(find.byType(AddInvestmentScreen), findsOneWidget);
        expect(_text(tester, nameField()), 'Grip FD');
      });
    }

    testWidgets('an empty name shows "Please enter a name" and sends nothing', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _fill(tester, amount: '100000');
      await _tapSubmit(tester);

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(harness.adds, isEmpty);
    });

    testWidgets('both errors show together', (tester) async {
      final harness = await _open(tester);

      await _fill(tester, amount: '0');
      await _tapSubmit(tester);

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(find.text('Enter an amount above 0'), findsOneWidget);
      expect(harness.adds, isEmpty);
    });

    testWidgets('a name of spaces is empty', (tester) async {
      final harness = await _open(tester);

      await _fill(tester, name: '    ');
      await _tapSubmit(tester);

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(harness.adds, isEmpty);
    });
  });

  group('a save that fails, and a retry', () {
    testWidgets('shows the message, keeps what was typed, button works again', (
      tester,
    ) async {
      final harness = await _open(tester);
      harness.notifier.failures = 1;

      await _fill(tester, name: 'Grip FD', amount: '1,50,000');
      await _tapSubmit(tester);

      expect(find.text(_failed), findsOneWidget);
      expect(find.byType(AddInvestmentScreen), findsOneWidget);
      expect(harness.detailVisits, isEmpty);
      expect(_text(tester, nameField()), 'Grip FD');
      expect(_text(tester, _amountField()), '1,50,000');
      expect(
        tester.widget<GradientButton>(_submit()).isLoading,
        isFalse,
        reason: 'the button is usable again',
      );
      expect(tester.widget<GradientButton>(_submit()).onPressed, isNotNull);
    });

    testWidgets('the retry sends the same id and the same amount', (
      tester,
    ) async {
      final harness = await _open(tester);
      harness.notifier.failures = 1;

      await _fill(tester, name: 'Grip FD', amount: '1,50,000');
      await _tapSubmit(tester);
      await _tapSubmit(tester);

      expect(harness.adds, hasLength(2));
      expect(harness.adds[1].id, harness.adds[0].id);
      expect(harness.adds[0].id, isNotEmpty);
      expect(harness.adds[1].initialAmount, 150000.0);
      expect(harness.adds[1].startDate, harness.adds[0].startDate);
      expect(find.text('Detail ${harness.adds[0].id}'), findsOneWidget);
    });

    testWidgets('a rebuild between attempts keeps the id', (tester) async {
      final harness = await _open(tester);
      harness.notifier.failures = 1;

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      // Rotate, grow the text, open the keyboard: the screen rebuilds.
      tester.view.physicalSize = const Size(842, 411);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await tester.pumpAndSettle();
      await _tapSubmit(tester);

      expect(harness.adds, hasLength(2));
      expect(harness.adds[1].id, harness.adds[0].id);
    });

    testWidgets('a second tap while saving sends once', (tester) async {
      final harness = await _open(tester);
      harness.notifier.gate = Completer<void>();

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await tester.tap(_submit());
      await tester.pump();
      expect(tester.widget<GradientButton>(_submit()).isLoading, isTrue);
      await tester.tap(_submit(), warnIfMissed: false);
      await tester.pump();
      expect(harness.adds, hasLength(1));

      harness.notifier.gate!.complete();
      await tester.pumpAndSettle();
      expect(harness.adds, hasLength(1));
      expect(harness.detailVisits, hasLength(1));
    });

    testWidgets('two taps in the same frame send once', (tester) async {
      final harness = await _open(tester);
      harness.notifier.gate = Completer<void>();

      await _fill(tester, name: 'Grip FD', amount: '100000');
      // No frame between them: the button has not yet been rebuilt as loading.
      await tester.tap(_submit());
      await tester.tap(_submit());
      await tester.pump();

      expect(harness.adds, hasLength(1));
      harness.notifier.gate!.complete();
      await tester.pumpAndSettle();
      expect(harness.adds, hasLength(1));
      expect(harness.detailVisits, hasLength(1));
    });

    testWidgets('two separate forms never share an id', (tester) async {
      final first = await _open(tester);
      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      final second = await _open(tester);
      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(first.adds.single.id, isNotEmpty);
      expect(second.adds.single.id, isNotEmpty);
      expect(second.adds.single.id, isNot(first.adds.single.id));
    });
  });

  group('a failed save is reported, without what the user typed', () {
    // Unlikely to occur in any other text.
    const secretName = 'ZqxSecretGripFD';
    late _MockFirebaseCrashlytics firebase;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
      registerFallbackValue(const <Object>[]);
    });

    setUp(() {
      firebase = _MockFirebaseCrashlytics();
      when(
        () => firebase.recordError(
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
        crashlytics: firebase,
      );
    });

    tearDown(() {
      CrashlyticsService.enableInDebugMode = false;
      LoggerService.crashlyticsServiceForTesting = null;
    });

    /// An error and a reason for each report made so far.
    List<Object?> reported() => verify(
      () => firebase.recordError(
        captureAny(),
        any(),
        reason: captureAny(named: 'reason'),
        fatal: any(named: 'fatal'),
        information: any(named: 'information'),
      ),
    ).captured;

    testWidgets('one report per failed attempt, with no name or amount', (
      tester,
    ) async {
      final harness = await _open(tester);
      harness.notifier.failures = 1;
      harness.notifier.error = StateError(
        'permission denied for users/uid-42/investments/$secretName '
        'amount 123456 owner someone@example.com',
      );

      await _fill(tester, name: secretName, amount: '123456');
      await _tapSubmit(tester);

      final report = reported();
      expect(report, hasLength(2), reason: 'an error and its reason');
      for (final part in report) {
        final text = '$part';
        expect(text, isNot(contains(secretName)));
        expect(text, isNot(contains('123456')));
        expect(text, isNot(contains('uid-42')));
        expect(text, isNot(contains('someone@example.com')));
      }
      expect(find.text(_failed), findsOneWidget);
    });

    testWidgets('a save that goes through reports nothing', (tester) async {
      await _open(tester);

      await _fill(tester, name: secretName, amount: '123456');
      await _tapSubmit(tester);

      verifyNever(
        () => firebase.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
          fatal: any(named: 'fatal'),
          information: any(named: 'information'),
        ),
      );
    });
  });

  group('the message after a save', () {
    testWidgets('confirmed: "Investment created successfully"', (tester) async {
      final harness = await _open(tester);
      harness.notifier.confirmed = true;

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(find.text(_created), findsOneWidget);
      expect(find.text(_offline), findsNothing);
    });

    testWidgets('only on this device: "Saved on this device..."', (
      tester,
    ) async {
      final harness = await _open(tester);
      harness.notifier.confirmed = false;

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(find.text(_offline), findsOneWidget);
      expect(find.text(_created), findsNothing);
    });

    testWidgets('no report (no amount): "Investment created successfully"', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      expect(harness.adds, hasLength(1));
      expect(find.text(_created), findsOneWidget);
    });
  });

  for (final opener in Opener.values) {
    group('after the save, opened by ${opener.name}', () {
      testWidgets('the form is replaced by the new investment', (tester) async {
        final harness = await _open(tester, opener: opener);
        final depth = harness.stack.depth;

        await _fill(tester, name: 'Grip FD', amount: '100000');
        await _tapSubmit(tester);

        final id = harness.adds.single.id!;
        expect(find.byType(AddInvestmentScreen), findsNothing);
        expect(find.text('Detail $id'), findsOneWidget);
        expect(harness.detailVisits, hasLength(1));
        expect(harness.detailVisits.single.id, id);
        final extra = harness.detailVisits.single.extra;
        expect(extra, isA<InvestmentEntity>());
        final entity = extra! as InvestmentEntity;
        expect(entity.id, id);
        expect(entity.name, 'Grip FD');
        expect(harness.stack.depth, depth, reason: 'replaced, not stacked');
      });

      testWidgets('Back returns to the page that opened the form', (
        tester,
      ) async {
        final harness = await _open(tester, opener: opener);
        final depth = harness.stack.depth;

        await _fill(tester, name: 'Grip FD', amount: '100000');
        await _tapSubmit(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('Opener'), findsOneWidget);
        expect(find.textContaining('Detail'), findsNothing);
        expect(find.byType(AddInvestmentScreen), findsNothing);
        expect(harness.stack.depth, depth - 1);
      });
    });
  }

  group('privacy mode', () {
    testWidgets('the readout reads "Hidden amount", visually and spoken', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester, privacy: true);

      await _fill(tester, amount: '150000');

      expect(find.text('Hidden amount'), findsOneWidget);
      expect(find.bySemanticsLabel('Hidden amount'), findsOneWidget);
      expect(find.text('₹1.5 L'), findsNothing);
      expect(find.text('₹1 L'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('lakh')), findsNothing);
      handle.dispose();
    });

    testWidgets('read from the stored flag and the stored privacy setting', (
      tester,
    ) async {
      await pumpAddForm(
        tester,
        now: _now,
        storedPrefs: {
          'feature_flag_first_investment_flow': true,
          'privacy_mode_enabled': true,
        },
      );

      expect(find.byType(MoreDetailsTile), findsOneWidget);
      await _fill(tester, amount: '150000');
      expect(find.text('Hidden amount'), findsOneWidget);
    });

    testWidgets('with the stored flag off it is today\'s form', (tester) async {
      await pumpAddForm(
        tester,
        size: const Size(1080, 3200),
        storedPrefs: {'feature_flag_first_investment_flow': false},
      );

      expect(find.byType(MoreDetailsTile), findsNothing);
      expect(find.text('Start Date (Optional)'), findsOneWidget);
    });

    testWidgets('with nothing stored it is today\'s form', (tester) async {
      await pumpAddForm(
        tester,
        size: const Size(1080, 3200),
        storedPrefs: const {},
      );

      expect(find.byType(MoreDetailsTile), findsNothing);
      expect(find.byType(StickyFormAction), findsNothing);
    });
  });

  group('currency', () {
    testWidgets(
      'EUR in More details: "Amount invested in EUR" and a euro sign',
      (tester) async {
        final harness = await _open(tester);

        await _openMore(tester);
        tester
            .widget<CurrencySelector>(find.byType(CurrencySelector))
            .onCurrencySelected('EUR');
        await tester.pumpAndSettle();
        await _fill(tester, name: 'Bund', amount: '1.500,50');

        final field = tester.widget<AppTextField>(
          find.byKey(AddInvestmentKeys.amount),
        );
        expect(field.label, 'Amount invested in EUR');
        expect(field.prefixText, '€');
        expect(
          find.descendant(
            of: find.byKey(AddInvestmentKeys.amount),
            matching: find.text('€'),
          ),
          findsWidgets,
          reason: 'the visible prefix',
        );
        expect(find.text('₹'), findsNothing);
        expect(find.textContaining('INR'), findsNothing);

        await _tapSubmit(tester);
        expect(harness.adds.single.currency, 'EUR');
        expect(harness.adds.single.initialAmount, 1500.5);
      },
    );

    testWidgets('the readout follows the currency: euros are not rupees', (
      tester,
    ) async {
      await _open(tester);

      await _openMore(tester);
      tester
          .widget<CurrencySelector>(find.byType(CurrencySelector))
          .onCurrencySelected('USD');
      await tester.pumpAndSettle();
      await _fill(tester, amount: '150000');

      expect(find.text('\$150K'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('picking a currency is counted, without the amount', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _openMore(tester);
      tester
          .widget<CurrencySelector>(find.byType(CurrencySelector))
          .onCurrencySelected('EUR');
      await tester.pumpAndSettle();

      expect(
        harness.analytics.loggedEvents.where(
          (e) => e.name == 'currency_selected',
        ),
        hasLength(1),
      );
    });
  });

  group('type chips set the structure, never a rate or a term', () {
    testWidgets('Fixed Deposit: structure set, rate and term empty, hint 7', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);

      final rate = _fieldLabelled('Expected Return Rate (% p.a.)');
      final tenure = _fieldLabelled('Tenure (Months)');
      expect(_text(tester, rate), isEmpty);
      expect(_text(tester, tenure), isEmpty);
      final rateField = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (w) =>
              w is AppTextField && w.label == 'Expected Return Rate (% p.a.)',
        ),
      );
      expect(rateField.hint, 'e.g. 7');

      await _fill(tester, name: 'FD - Senior citizen');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.type, InvestmentType.fixedDeposit);
      expect(call.expectedRate, isNull);
      expect(call.tenureMonths, isNull);
      expect(call.maturityDate, isNull);
      expect(call.interestPayoutMode, InterestPayoutMode.cumulative);
      expect(call.compoundingFrequency, CompoundingFrequency.quarterly);
      // A payout schedule is the user's to state: with one, the app schedules
      // an income reminder for it.
      expect(call.incomeFrequency, isNull);
      expect(call.riskLevel, isNull);
      expect(call.name, 'FD - Senior citizen');
    });

    testWidgets('a chip never fills the name', (tester) async {
      await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);

      expect(_text(tester, nameField()), isEmpty);
    });

    testWidgets('no chip puts a rate or a term in a field', (tester) async {
      await _open(tester);

      for (final type in InvestmentType.values) {
        await _tapChip(tester, type);
        await _openMoreIfClosed(tester);
        for (final label in [
          'Expected Return Rate (% p.a.)',
          'Tenure (Months)',
        ]) {
          final field = _fieldLabelled(label);
          if (field.evaluate().isNotEmpty) {
            expect(
              _text(tester, field),
              isEmpty,
              reason: '${type.name} $label',
            );
          }
        }
      }
    });

    testWidgets(
      'each type\'s typical rate is the hint of the empty rate field',
      (tester) async {
        await _open(tester);
        final hints = <InvestmentType, String>{
          InvestmentType.p2pLending: 'e.g. 12',
          InvestmentType.fixedDeposit: 'e.g. 7',
          InvestmentType.gold: 'e.g. 2.5',
          InvestmentType.bonds: 'e.g. 9',
          InvestmentType.realEstate: 'e.g. 3',
        };

        await _openMore(tester);
        for (final MapEntry(:key, :value) in hints.entries) {
          await _tapChip(tester, key);
          final field = tester.widget<AppTextField>(
            find.byWidgetPredicate(
              (w) =>
                  w is AppTextField &&
                  w.label == 'Expected Return Rate (% p.a.)',
            ),
          );
          expect(field.hint, value, reason: key.name);
        }
      },
    );

    testWidgets('a type with no typical rate keeps the generic hint', (
      tester,
    ) async {
      await _open(tester);

      await _tapChip(tester, InvestmentType.gold);
      await _tapChip(tester, InvestmentType.invoiceDiscounting);
      await _openMore(tester);

      final field = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (w) =>
              w is AppTextField && w.label == 'Expected Return Rate (% p.a.)',
        ),
      );
      expect(field.hint, 'e.g. 7.5');
    });

    testWidgets('a rate the user typed survives a chip change', (tester) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '7.25',
      );
      await tester.pump();
      await _tapChip(tester, InvestmentType.p2pLending);

      expect(
        _text(tester, _fieldLabelled('Expected Return Rate (% p.a.)')),
        '7.25',
      );

      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '',
      );
      await tester.pump();
      final field = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (w) =>
              w is AppTextField && w.label == 'Expected Return Rate (% p.a.)',
        ),
      );
      expect(field.hint, 'e.g. 12');

      await _fill(tester, name: 'LenDenClub');
      await _tapSubmit(tester);
      expect(harness.adds.single.expectedRate, isNull);
    });

    testWidgets('untouched structure follows the chip: FD then P2P', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _tapChip(tester, InvestmentType.p2pLending);
      await _fill(tester, name: 'LenDenClub');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.interestPayoutMode, InterestPayoutMode.periodic);
      expect(call.compoundingFrequency, CompoundingFrequency.none);
      expect(call.incomeFrequency, isNull);
    });

    testWidgets('the first chip tap sets the structure of the default type', (
      tester,
    ) async {
      final harness = await _open(tester);

      // P2P Lending is already selected; choosing it again is a choice.
      await _tapChip(tester, InvestmentType.p2pLending);
      await _fill(tester, name: 'LenDenClub');
      await _tapSubmit(tester);

      expect(
        harness.adds.single.interestPayoutMode,
        InterestPayoutMode.periodic,
      );
      expect(harness.adds.single.incomeFrequency, isNull);
    });

    testWidgets('a type with no template clears the structure it set', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _tapChip(tester, InvestmentType.stocks);
      await _fill(tester, name: 'Infosys');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.type, InvestmentType.stocks);
      expect(call.interestPayoutMode, isNull);
      expect(call.compoundingFrequency, isNull);
      expect(call.incomeFrequency, isNull);
    });

    testWidgets('a choice made in More details survives a chip change', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.ensureVisible(find.text('At Maturity'));
      await tester.tap(find.text('At Maturity'));
      await tester.pumpAndSettle();
      await _tapChip(tester, InvestmentType.bonds);
      await _fill(tester, name: 'NCD');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.type, InvestmentType.bonds);
      expect(call.interestPayoutMode, InterestPayoutMode.atMaturity);
      expect(call.incomeFrequency, isNull);
    });

    testWidgets('a pick that equals another chip\'s default survives a round '
        'trip of chips', (tester) async {
      final harness = await _open(tester);

      // Fixed Deposit sets Cumulative and Quarterly. The user picks Periodic
      // and Simple Interest, which are what P2P Lending sets.
      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.ensureVisible(find.text('Periodic'));
      await tester.tap(find.text('Periodic'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simple Interest'));
      await tester.tap(find.text('Simple Interest'));
      await tester.pumpAndSettle();
      await _tapChip(tester, InvestmentType.p2pLending);
      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.type, InvestmentType.fixedDeposit);
      expect(call.interestPayoutMode, InterestPayoutMode.periodic);
      expect(call.compoundingFrequency, CompoundingFrequency.none);
    });

    testWidgets('a chip never sets an income frequency, whatever the type', (
      tester,
    ) async {
      for (final type in InvestmentType.values) {
        // A new form for each type: a save closes the one before.
        final harness = await _open(tester);
        await _tapChip(tester, type);
        await _fill(tester, name: 'Any ${type.name}');
        await _tapSubmit(tester);

        expect(
          harness.adds.single.incomeFrequency,
          isNull,
          reason: 'a ${type.name} chip must not schedule income reminders',
        );
      }
    });

    testWidgets('an income frequency the user chose survives a chip change', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      final monthly = find.bySemanticsLabel('Monthly income frequency');
      await tester.ensureVisible(monthly);
      await tester.pumpAndSettle();
      await tester.tap(monthly);
      await tester.pumpAndSettle();
      await _tapChip(tester, InvestmentType.gold);
      await _fill(tester, name: 'SGB');
      await _tapSubmit(tester);

      expect(harness.adds.single.incomeFrequency, IncomeFrequency.monthly);
      handle.dispose();
    });

    testWidgets('a chip never sets a risk level', (tester) async {
      final harness = await _open(tester);

      for (final type in [InvestmentType.bonds, InvestmentType.p2pLending]) {
        await _tapChip(tester, type);
      }
      await _fill(tester, name: 'NCD');
      await _tapSubmit(tester);

      expect(harness.adds.single.riskLevel, isNull);
    });

    testWidgets('choosing a type that shows no rate field saves no rate', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.stocks);
      await _fill(tester, name: 'Infosys', amount: '50000');
      await _tapSubmit(tester);

      expect(harness.adds.single.expectedRate, isNull);
      expect(harness.adds.single.tenureMonths, isNull);
      expect(harness.adds.single.initialAmount, 50000.0);
    });
  });

  group('a template picked on the Overview', () {
    testWidgets(
      'Fixed Deposit: the type and structure, no name, rate or term',
      (tester) async {
        final harness = await _open(
          tester,
          template: InvestmentTemplates.fixedDeposit,
        );

        final selector = tester.widget<TypeSelector<InvestmentType>>(
          find.byType(TypeSelector<InvestmentType>),
        );
        expect(selector.selectedValue, InvestmentType.fixedDeposit);
        expect(_text(tester, nameField()), isEmpty);
        await _openMore(tester);
        expect(
          _text(tester, _fieldLabelled('Expected Return Rate (% p.a.)')),
          isEmpty,
        );
        expect(_text(tester, _fieldLabelled('Tenure (Months)')), isEmpty);
        final rateField = tester.widget<AppTextField>(
          find.byWidgetPredicate(
            (w) =>
                w is AppTextField && w.label == 'Expected Return Rate (% p.a.)',
          ),
        );
        expect(rateField.hint, 'e.g. 7');
        expect(
          harness.analytics.loggedEvents.where(
            (e) => e.name == 'template_selected',
          ),
          hasLength(1),
        );

        await _fill(tester, name: 'FD - SBI', amount: '100000');
        await _tapSubmit(tester);
        final call = harness.adds.single;
        expect(call.expectedRate, isNull);
        expect(call.tenureMonths, isNull);
        expect(call.maturityDate, isNull);
        expect(call.interestPayoutMode, InterestPayoutMode.cumulative);
        expect(call.compoundingFrequency, CompoundingFrequency.quarterly);
        expect(call.incomeFrequency, isNull);
        expect(call.riskLevel, isNull);
      },
    );

    testWidgets('Recurring Deposit: its own structure, not the FD one', (
      tester,
    ) async {
      final harness = await _open(
        tester,
        template: InvestmentTemplates.recurringDeposit,
      );

      await _fill(tester, name: 'RD - SBI');
      await _tapSubmit(tester);

      final call = harness.adds.single;
      expect(call.type, InvestmentType.fixedDeposit);
      expect(call.interestPayoutMode, InterestPayoutMode.atMaturity);
      expect(call.incomeFrequency, isNull);
    });

    testWidgets('a template far along the row is scrolled into view', (
      tester,
    ) async {
      await _open(tester, template: InvestmentTemplates.gold);

      final rect = tester.getRect(_chip(InvestmentType.gold));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(411));
    });
  });

  group('analytics', () {
    List<Map<String, Object>> enhanced(FormHarness harness) => [
      for (final e in harness.analytics.loggedEvents)
        if (e.name == 'enhanced_fields_used') e.parameters!,
    ];

    testWidgets('the default start date is not counted as a field used', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(enhanced(harness), isEmpty);
    });

    testWidgets('what a type chip sets is not counted as a field used', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _fill(tester, name: 'Grip FD', amount: '100000');
      await _tapSubmit(tester);

      expect(harness.adds.single.interestPayoutMode, isNotNull);
      expect(harness.adds.single.compoundingFrequency, isNotNull);
      expect(enhanced(harness), isEmpty);
    });

    testWidgets('a payout mode the user changed is counted, alone', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.ensureVisible(find.text('At Maturity'));
      await tester.tap(find.text('At Maturity'));
      await tester.pumpAndSettle();
      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      expect(enhanced(harness).single['fields'], 'payout_mode');
    });

    testWidgets('picking the value the chip set is still counted', (
      tester,
    ) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.ensureVisible(find.text('Cumulative'));
      await tester.tap(find.text('Cumulative'));
      await tester.pumpAndSettle();
      // Quarterly is also an income frequency: take the compounding one.
      final quarterly = find.descendant(
        of: find
            .ancestor(
              of: find.text('Compounding Frequency (Optional)'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.text('Quarterly'),
      );
      await tester.ensureVisible(quarterly);
      await tester.tap(quarterly);
      await tester.pumpAndSettle();
      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      expect(enhanced(harness).single['fields'], 'payout_mode,compounding');
    });

    testWidgets('a rate the user typed is counted, alone', (tester) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '7.25',
      );
      await _fill(tester, name: 'Grip FD');
      await _tapSubmit(tester);

      expect(enhanced(harness).single['fields'], 'expected_rate');
    });

    testWidgets('a start date the user picked is counted', (tester) async {
      final harness = await _open(tester);
      await _fill(tester, name: 'Grip FD', amount: '100000');

      await tester.tap(find.byType(StartDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _tapSubmit(tester);

      expect(enhanced(harness).single['fields'], 'start_date');
    });

    testWidgets('no event carries the name or the amount', (tester) async {
      final harness = await _open(tester);

      await _tapChip(tester, InvestmentType.fixedDeposit);
      await _openMore(tester);
      await tester.enterText(
        _fieldLabelled('Expected Return Rate (% p.a.)'),
        '7.25',
      );
      await _fill(tester, name: 'Secret Grip FD', amount: '123456');
      await _tapSubmit(tester);

      expect(harness.analytics.loggedEvents, isNotEmpty);
      for (final event in harness.analytics.loggedEvents) {
        for (final value in (event.parameters ?? {}).values) {
          final text = value.toString();
          expect(text, isNot(contains('Secret')), reason: event.name);
          expect(text, isNot(contains('123456')), reason: event.name);
          expect(text, isNot(contains('123,456')), reason: event.name);
        }
      }
    });
  });

  group('editing an investment', () {
    testWidgets('keeps the form it has today, flag on or off', (tester) async {
      final investment = InvestmentEntity(
        id: 'inv-1',
        name: 'Grip FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        currency: 'INR',
        startDate: DateTime(2026, 10, 11),
      );
      final harness = await pumpAddForm(
        tester,
        flagOn: true,
        now: _now,
        edit: investment,
        size: const Size(1080, 3200),
      );

      expect(find.text('Edit Investment'), findsOneWidget);
      expect(find.byType(MoreDetailsTile), findsNothing);
      expect(find.byType(StickyFormAction), findsNothing);
      expect(find.text('Start Date (Optional)'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Amount invested in INR'), findsNothing);
      expect(harness.adds, isEmpty);
    });
  });
}

/// Opens More details unless it is open.
Future<void> _openMoreIfClosed(WidgetTester tester) async {
  if (find.byType(CurrencySelector).evaluate().isNotEmpty) return;
  await _openMore(tester);
}
