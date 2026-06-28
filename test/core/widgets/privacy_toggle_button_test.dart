import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget(Widget child) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('PrivacyToggleButton', () {
    testWidgets('has semantic label', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));
      final context = tester.element(find.byType(PrivacyToggleButton));
      expect(find.bySemanticsLabel(AppLocalizations.of(context).tooltipHideAmounts), findsOneWidget);
    });

    testWidgets('toggles semantics when tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));
      final context = tester.element(find.byType(PrivacyToggleButton));
      final hideAmounts = AppLocalizations.of(context).tooltipHideAmounts;
      final showAmounts = AppLocalizations.of(context).tooltipShowAmounts;

      expect(find.bySemanticsLabel(hideAmounts), findsOneWidget);

      await tester.tap(find.byType(PrivacyToggleButton));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(showAmounts), findsOneWidget);
    });

    testWidgets('has tooltip', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));
      final context = tester.element(find.byType(PrivacyToggleButton));
      expect(find.byTooltip(AppLocalizations.of(context).tooltipHideAmounts), findsOneWidget);
    });

    testWidgets('is tappable as a button', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));
      await tester.tap(find.byType(PrivacyToggleButton));
      await tester.pump();
      expect(find.byType(PrivacyToggleButton), findsOneWidget);
    });
  });

  group('CompactPrivacyToggle', () {
    testWidgets('has tooltip for accessibility', (tester) async {
      await tester.pumpWidget(buildTestWidget(const CompactPrivacyToggle()));
      final context = tester.element(find.byType(CompactPrivacyToggle));
      expect(find.byTooltip(AppLocalizations.of(context).tooltipHideAmounts), findsOneWidget);
    });

    testWidgets('toggles tooltip when tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(const CompactPrivacyToggle()));
      final context = tester.element(find.byType(CompactPrivacyToggle));
      final hideAmounts = AppLocalizations.of(context).tooltipHideAmounts;
      final showAmounts = AppLocalizations.of(context).tooltipShowAmounts;

      expect(find.byTooltip(hideAmounts), findsOneWidget);

      await tester.tap(find.byType(CompactPrivacyToggle));
      await tester.pumpAndSettle();

      expect(find.byTooltip(showAmounts), findsOneWidget);
    });
  });
}
