import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

void main() {
  Future<void> pumpWidget(
    WidgetTester tester,
    Widget child, {
    required bool privacyModeEnabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      'privacy_mode_enabled': privacyModeEnabled,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  group('CompactAmountText Accessibility', () {
    testWidgets('Normal mode: Should have accessible label with full amount', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        const CompactAmountText(
          amount: 150000,
          compactText: '₹1.5L',
          currencySymbol: '₹',
          locale: 'en_IN',
        ),
        privacyModeEnabled: false,
      );

      // The screen reader hears the amount as shown, in lakh for INR, not
      // Western-grouped '150,000' (A18).
      final semantics = tester.getSemantics(find.byType(CompactAmountText));
      expect(semantics.label, '1.5 lakh rupees');

      // Verify hint is present
      expect(semantics.hint, contains('copy exact amount'));
    });

    testWidgets('Privacy mode: Should have "Hidden amount" label', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        const CompactAmountText(amount: 150000, compactText: '₹1.5L'),
        privacyModeEnabled: true,
      );

      final semantics = tester.getSemantics(find.byType(CompactAmountText));

      expect(semantics.label, 'Hidden amount');
      // Should NOT read bullets
      expect(semantics.label, isNot(contains('•')));
    });

    testWidgets('Normal mode: Should support long press action via Semantics', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        const CompactAmountText(amount: 150000, compactText: '₹1.5L'),
        privacyModeEnabled: false,
      );

      final semanticsHandle = tester.ensureSemantics();

      // Verify usage of onLongPress in semantics
      expect(
        tester.getSemantics(find.byType(CompactAmountText)),
        matchesSemantics(
          hasLongPressAction: true,
          hint: 'Double tap and hold to copy exact amount',
        ),
      );

      // Perform long press to verify action works (shows snackbar)
      await tester.longPress(find.byType(CompactAmountText));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('1,50,000.00'), findsOneWidget);

      semanticsHandle.dispose();
    });
  });

  group('CompactAmountText Copy Button Tooltip', () {
    testWidgets(
      'Snackbar copy button should have tooltip "Copy amount"',
      (tester) async {
        await pumpWidget(
          tester,
          const CompactAmountText(amount: 105000000, compactText: '₹1.05Cr'),
          privacyModeEnabled: false,
        );

        // Long press to reveal the full-amount snackbar
        await tester.longPress(find.byType(CompactAmountText));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);

        // The copy IconButton must carry the updated tooltip 'Copy amount'
        expect(find.byTooltip('Copy amount'), findsOneWidget);
      },
    );

    testWidgets(
      'Snackbar copy button should NOT have the old tooltip "Copy"',
      (tester) async {
        await pumpWidget(
          tester,
          const CompactAmountText(amount: 105000000, compactText: '₹1.05Cr'),
          privacyModeEnabled: false,
        );

        await tester.longPress(find.byType(CompactAmountText));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);

        // Regression: the previous tooltip 'Copy' must no longer exist
        expect(find.byTooltip('Copy'), findsNothing);
      },
    );

    testWidgets(
      'Copy button with "Copy amount" tooltip is tappable and shows copied snackbar',
      (tester) async {
        await pumpWidget(
          tester,
          const CompactAmountText(amount: 150000, compactText: '₹1.5L'),
          privacyModeEnabled: false,
        );

        // Show the full-amount snackbar via long press
        await tester.longPress(find.byType(CompactAmountText));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Copy amount'), findsOneWidget);

        // Tap the copy button
        await tester.tap(find.byTooltip('Copy amount'));
        await tester.pumpAndSettle();

        // A confirmation snackbar should appear after copying
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'Copy button tooltip is "Copy amount" regardless of amount value',
      (tester) async {
        // Boundary / negative case: zero amount
        await pumpWidget(
          tester,
          const CompactAmountText(amount: 0, compactText: '₹0'),
          privacyModeEnabled: false,
        );

        await tester.longPress(find.byType(CompactAmountText));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Copy amount'), findsOneWidget);
        expect(find.byTooltip('Copy'), findsNothing);
      },
    );
  });

  group('CompactAmountText currency and locale come from the caller', () {
    // Only privacy mode is provided: the widget must not need the currency
    // settings providers, which screens and tests pass in as a NumberFormat.
    Future<SemanticsNode> labelOf(
      WidgetTester tester,
      CompactAmountText child,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privacyModeProvider.overrideWith(_PrivacyOff.new)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Center(child: child)),
          ),
        ),
      );
      return tester.getSemantics(find.byType(CompactAmountText));
    }

    testWidgets('a USD amount is read in dollars with Western grouping', (
      tester,
    ) async {
      final semantics = await labelOf(
        tester,
        const CompactAmountText(
          amount: 1500000,
          compactText: r'$1.5M',
          currencySymbol: r'$',
          locale: 'en_US',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(semantics.label, '1,500,000 dollars');
    });

    testWidgets('an INR amount is read in lakh', (tester) async {
      final semantics = await labelOf(
        tester,
        const CompactAmountText(
          amount: 150000,
          compactText: '₹1.5L',
          currencySymbol: '₹',
          locale: 'en_IN',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(semantics.label, '1.5 lakh rupees');
    });
  });
}
