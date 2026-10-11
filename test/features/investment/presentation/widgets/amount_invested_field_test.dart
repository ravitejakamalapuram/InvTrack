// A40 (#783) PR-2: the optional "amount invested" field of the add investment
// form. It names its currency in the label and the prefix, never shows the
// rupee sign for another currency, says it is optional while empty, reads back
// what was typed as a short amount (the guard against a misplaced separator),
// and keeps the readout private in privacy mode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/amount_invested_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

late TextEditingController _controller;
final _formKey = GlobalKey<FormState>();

Widget _host({
  String currency = 'INR',
  bool privacy = false,
  ValueChanged<String>? onChanged,
}) => ProviderScope(
  overrides: [isPrivacyModeActiveProvider.overrideWithValue(privacy)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: AmountInvestedField(
            controller: _controller,
            currencyCode: currency,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  ),
);

Finder get _input => find.descendant(
  of: find.byKey(AddInvestmentKeys.amount),
  matching: find.byType(EditableText),
);

void main() {
  setUp(() => _controller = TextEditingController());
  tearDown(() => _controller.dispose());

  group('currency', () {
    AppTextField field(WidgetTester tester) =>
        tester.widget<AppTextField>(find.byKey(AddInvestmentKeys.amount));

    testWidgets('INR: label names the currency, prefix is the rupee sign', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      expect(field(tester).label, 'Amount invested in INR');
      expect(field(tester).prefixText, '₹');
      expect(find.text('Amount invested in INR'), findsWidgets);
    });

    testWidgets('EUR: label and prefix follow, no rupee sign anywhere', (
      tester,
    ) async {
      await tester.pumpWidget(_host(currency: 'EUR'));
      await tester.enterText(_input, '5');
      await tester.pump();

      expect(field(tester).label, 'Amount invested in EUR');
      expect(field(tester).prefixText, '€');
      expect(find.text('€'), findsOneWidget, reason: 'the visible prefix');
      expect(find.text('₹'), findsNothing);
      expect(find.textContaining('INR'), findsNothing);
    });

    testWidgets('the hint is an example in the currency\'s own grouping', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      expect(
        tester.widget<AppTextField>(find.byKey(AddInvestmentKeys.amount)).hint,
        'e.g. 1,00,000',
      );

      await tester.pumpWidget(_host(currency: 'USD'));
      expect(
        tester.widget<AppTextField>(find.byKey(AddInvestmentKeys.amount)).hint,
        'e.g. 100,000',
      );
    });

    testWidgets('changing the currency updates label, prefix and hint', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpWidget(_host(currency: 'GBP'));

      expect(field(tester).label, 'Amount invested in GBP');
      expect(field(tester).prefixText, '£');
      expect(field(tester).hint, 'e.g. 100,000');
      expect(find.textContaining('INR'), findsNothing);
      expect(find.text('₹'), findsNothing);
    });
  });

  group('the line under the field', () {
    testWidgets('empty: it says the amount is optional', (tester) async {
      await tester.pumpWidget(_host());

      expect(find.text('Optional. You can add it later.'), findsOneWidget);
    });

    testWidgets('a spaces-only field still says optional', (tester) async {
      await tester.pumpWidget(_host());
      _controller.text = '   ';
      await tester.pump();

      expect(find.text('Optional. You can add it later.'), findsOneWidget);
    });

    testWidgets('100000 reads back as ₹1 L, 1,50,000 as ₹1.5 L', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      await tester.enterText(_input, '100000');
      await tester.pump();
      expect(find.text('₹1 L'), findsOneWidget);
      expect(find.text('Optional. You can add it later.'), findsNothing);

      await tester.enterText(_input, '1,50,000');
      await tester.pump();
      expect(find.text('₹1.5 L'), findsOneWidget);
    });

    testWidgets('1,50 reads back as ₹1.5: the readout shows a misread', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      await tester.enterText(_input, '1,50');
      await tester.pump();

      expect(find.text('₹1.5'), findsOneWidget);
    });

    testWidgets('a text with a problem shows no readout and no hint', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      for (final text in ['0', '1,5000', '1000000000000000']) {
        await tester.enterText(_input, text);
        await tester.pump();
        expect(
          find.text('Optional. You can add it later.'),
          findsNothing,
          reason: text,
        );
        expect(find.textContaining('₹1'), findsNothing, reason: text);
      }
    });

    testWidgets('the readout is spoken in full', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host());

      await tester.enterText(_input, '150000');
      await tester.pump();

      expect(find.bySemanticsLabel('1.5 lakh rupees'), findsOneWidget);
      handle.dispose();
    });
  });

  group('privacy mode', () {
    testWidgets('the readout reads "Hidden amount", visually and spoken', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(privacy: true));

      await tester.enterText(_input, '150000');
      await tester.pump();

      expect(find.text('Hidden amount'), findsOneWidget);
      expect(find.bySemanticsLabel('Hidden amount'), findsOneWidget);
      expect(find.text('₹1.5 L'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('lakh')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('1.5 L')), findsNothing);
      handle.dispose();
    });

    testWidgets('an empty field still says optional', (tester) async {
      await tester.pumpWidget(_host(privacy: true));

      expect(find.text('Optional. You can add it later.'), findsOneWidget);
      expect(find.text('Hidden amount'), findsNothing);
    });
  });

  group('validation', () {
    Future<String?> errorFor(WidgetTester tester, String text) async {
      await tester.pumpWidget(_host());
      await tester.enterText(_input, text);
      _formKey.currentState!.validate();
      await tester.pump();
      for (final message in [
        'Enter an amount above 0',
        'Enter a valid amount. Check the commas and the decimal point.',
        'That amount is too large',
      ]) {
        if (find.text(message).evaluate().isNotEmpty) return message;
      }
      return null;
    }

    testWidgets('blank and a good amount are valid', (tester) async {
      expect(await errorFor(tester, ''), isNull);
      expect(await errorFor(tester, '100000'), isNull);
      expect(await errorFor(tester, '1,00,000'), isNull);
    });

    testWidgets('0, 0.00 and -5 are "Enter an amount above 0"', (tester) async {
      for (final text in ['0', '0.00', '-5']) {
        expect(
          await errorFor(tester, text),
          'Enter an amount above 0',
          reason: text,
        );
      }
    });

    testWidgets('an unreadable amount says so, not "above 0"', (tester) async {
      expect(
        await errorFor(tester, '1,5000'),
        'Enter a valid amount. Check the commas and the decimal point.',
      );
    });

    testWidgets('16 digits is "That amount is too large"', (tester) async {
      expect(
        await errorFor(tester, '1000000000000000'),
        'That amount is too large',
      );
    });
  });

  group('typing', () {
    testWidgets('only digits, marks and a minus get through', (tester) async {
      await tester.pumpWidget(_host());

      await tester.enterText(_input, 'ab1,2.3-c ');

      expect(_controller.text, '1,2.3-');
    });

    testWidgets('a long paste is cut at 20 characters, with no counter', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      await tester.enterText(_input, '1' * 40);
      await tester.pump();

      expect(_controller.text.length, 20);
      expect(find.text('20/20'), findsNothing);
      expect(find.textContaining('/20'), findsNothing);
    });

    testWidgets('the keyboard offers decimal numbers', (tester) async {
      await tester.pumpWidget(_host());

      final field = tester.widget<EditableText>(_input);
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });

    testWidgets('onChanged hears each edit', (tester) async {
      final heard = <String>[];
      await tester.pumpWidget(_host(onChanged: heard.add));

      await tester.enterText(_input, '12');

      expect(heard, ['12']);
    });
  });
}
