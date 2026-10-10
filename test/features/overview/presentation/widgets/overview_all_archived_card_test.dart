// A17 / GAP1-05: when every investment is archived, Overview explains why the
// totals are empty instead of showing the first-run onboarding. The card must
// read correctly to a screen reader too: a heading, the explanation, and a
// button that says where it goes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_all_archived_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

const _title = 'All your investments are archived';
const _body =
    'Overview totals, goals and FIRE leave archived investments out, so they '
    'show nothing for now. Your archived investments are still in the '
    'Investments tab.';

Future<void> _pump(WidgetTester tester, VoidCallback onViewInvestments) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OverviewAllArchivedCard(onViewInvestments: onViewInvestments),
        ),
      ),
    );

void main() {
  testWidgets('the title is a heading for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () {});

    expect(
      tester.getSemantics(find.text(_title)),
      containsSemantics(label: _title, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('the body explains the exclusion and where the items are', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () {});

    expect(find.text(_body), findsOneWidget);
    expect(
      tester.getSemantics(find.text(_body)),
      containsSemantics(label: _body),
    );
    handle.dispose();
  });

  testWidgets('the action is a button named View investments and works', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await _pump(tester, () => opened++);

    expect(
      tester.getSemantics(
        find.widgetWithText(FilledButton, 'View investments'),
      ),
      containsSemantics(
        label: 'View investments',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('View investments'));
    expect(opened, 1);
    handle.dispose();
  });
}
