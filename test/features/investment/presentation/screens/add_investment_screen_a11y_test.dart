import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

// Mock Notifier that does nothing
class MockInvestmentNotifier extends InvestmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
}

void main() {
  testWidgets('AddInvestmentScreen accessibility test', (tester) async {
    // Setup overrides
    final overrides = [
      currencyCodeProvider.overrideWithValue('USD'),
      currencySymbolProvider.overrideWithValue('\$'),
      currencyLocaleProvider.overrideWithValue('en_US'),
      investmentNotifierProvider.overrideWith(MockInvestmentNotifier.new),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: AddInvestmentScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify "Investment Type" selector
    // Scroll down to find dynamic fields.
    final scrollable = find.byType(Scrollable).first;

    // 2. Check "Start Date" picker semantics
    // It might be hidden if config doesn't show it, but P2P Lending usually shows most fields.
    // Let's check if we can find "Start Date (Optional)" text.
    expect(find.text('Start Date (Optional)'), findsOneWidget);

    // Find the GlassCard or GestureDetector that allows picking date.
    // Currently it likely lacks proper semantics, so we look for what we *expect* to have after fix.
    // Or we can look for what acts as the button.
    // The button is "When did you invest?" text inside the card if not set.

    final startDateText = find.text('When did you invest?');
    expect(startDateText, findsOneWidget);

    // 3. Check Enum Chips (Risk Level, Payout Mode)
    // Find "Medium Risk" risk level chip
    final mediumRiskFinder = find.text('Medium Risk');
    await tester.scrollUntilVisible(
      mediumRiskFinder,
      100,
      scrollable: scrollable,
    );
    expect(mediumRiskFinder, findsOneWidget);

    // Find "Monthly" payout mode chip
    final monthlyPayoutFinder = find.text('Monthly');
    await tester.scrollUntilVisible(
      monthlyPayoutFinder,
      100,
      scrollable: scrollable,
    );
    expect(monthlyPayoutFinder, findsOneWidget);

    // We expect these to be buttons with proper labels.
    // Currently they are just gesture detectors without button semantics.

    // Use Semantics check
    // For Start Date
    // First verify the widget exists
    final semanticsWidget = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Select Start Date',
    );
    // Ensure it's visible by scrolling to it (it wraps the GlassCard)
    await tester.scrollUntilVisible(
      semanticsWidget,
      100,
      scrollable: scrollable,
    );
    expect(
      semanticsWidget,
      findsOneWidget,
      reason: 'Semantics widget should exist in the tree',
    );

    // Verify semantics on the widget we found
    final semanticsNode = tester.getSemantics(semanticsWidget);
    // Access data via getSemanticsData() if available, or assume it's data
    final semanticsData = (semanticsNode as dynamic).getSemanticsData();
    expect(
      semanticsData.label,
      'Select Start Date',
      reason: 'Start Date picker should have correct label',
    );
    // ignore: deprecated_member_use
    expect(
      semanticsData.hasFlag(SemanticsFlag.isButton),
      isTrue,
      reason: 'Start Date picker should be a button',
    );
    expect(
      semanticsData.hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'Start Date picker should be tappable',
    );

    // For Risk Level "Medium Risk"
    final mediumRiskSemantics = find.bySemanticsLabel('Medium Risk');
    expect(
      mediumRiskSemantics,
      findsOneWidget,
      reason: 'Risk Level chip should have semantic label',
    );
    final mediumRiskNode = tester.getSemantics(mediumRiskSemantics);
    final mediumRiskData = (mediumRiskNode as dynamic).getSemanticsData();
    // ignore: deprecated_member_use
    expect(
      mediumRiskData.hasFlag(SemanticsFlag.isButton),
      isTrue,
      reason: 'Risk Level chip should be a button',
    );
    expect(
      mediumRiskData.hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'Risk Level chip should be tappable',
    );

    // For Payout Mode "Monthly" - Not shown for P2P Lending by default, so skipping.
    // We already verified _buildEnumChip works with Risk Level.

    // 4. Check Income Frequency (uses _buildFrequencyChip)
    // This is ALWAYS visible at the bottom of the form.
    // Find "Monthly income frequency" semantics label.
    final monthlyFrequencyFinder = find.bySemanticsLabel(
      'Monthly income frequency',
    );

    // Scroll to ensure it is visible (it's at the bottom)
    await tester.scrollUntilVisible(
      monthlyFrequencyFinder,
      500,
      scrollable: scrollable,
    );
    expect(
      monthlyFrequencyFinder,
      findsOneWidget,
      reason: 'Monthly income frequency chip should exist',
    );

    final monthlyFreqNode = tester.getSemantics(monthlyFrequencyFinder);
    final monthlyFreqData = (monthlyFreqNode as dynamic).getSemanticsData();

    expect(monthlyFreqData.label, 'Monthly income frequency');
    // ignore: deprecated_member_use
    expect(
      monthlyFreqData.hasFlag(SemanticsFlag.isButton),
      isTrue,
      reason: 'Frequency chip should be a button',
    );
    expect(
      monthlyFreqData.hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'Frequency chip should be tappable (onTap added)',
    );
  });
}
