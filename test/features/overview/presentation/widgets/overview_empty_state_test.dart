// Tests for the empty-state "advertised vs real" XIRR demo (A20, ADOPT-03).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpEmptyState(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: OverviewEmptyState()),
        ),
      ),
    );
    // Let the advertised-to-real animation finish.
    await tester.pumpAndSettle();
  }

  group('OverviewEmptyState XIRR demo', () {
    testWidgets('leads with P2P: 12% advertised, 6.3% real', (tester) async {
      await pumpEmptyState(tester);

      expect(
        find.text('P2P platforms advertise 12%. What did you really earn?'),
        findsOneWidget,
      );
      expect(find.text('12.0%'), findsOneWidget);
      expect(find.text('6.3%'), findsOneWidget);
      expect(find.text('Advertised'), findsOneWidget);
      expect(find.text('Your XIRR'), findsOneWidget);
    });

    testWidgets('caption blames fees and a default, not compounding', (
      tester,
    ) async {
      await pumpEmptyState(tester);

      expect(
        find.text(
          'Platform fees and one defaulted loan cut 12% to 6.3% a year.',
        ),
        findsOneWidget,
      );
      // Compounding raises a 7% FD to 7.19%; it never lowers the return.
      expect(find.textContaining('compounding'), findsNothing);
      expect(find.text('7.0%'), findsNothing);
      expect(find.text('6.2%'), findsNothing);
    });

    testWidgets('screen readers hear the final comparison once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpEmptyState(tester);

      expect(
        find.semantics.byLabel(
          'Advertised 12.0%. Your XIRR after fees and one defaulted loan: '
          '6.3%.',
        ),
        findsOneWidget,
      );
      // The animated figures are not read out on their own.
      expect(find.semantics.byLabel('6.3%'), findsNothing);
      semantics.dispose();
    });
  });
}
