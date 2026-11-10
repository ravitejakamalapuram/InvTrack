// #845 (A80): a backup leaves the currency cell empty for a record whose
// currency the app only assumed, and an older release cannot restore a
// valuation row with an empty currency. Help & FAQ says both.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/screens/help_faq_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      800,
      20000,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('the backup answer explains empty currency cells and the older '
      'release limit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HelpFaqScreen(
          showDeveloperFaq: false,
          showPortfolioHealthFaq: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('empty Currency', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('older version of InvTrack', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the Tax-Year PDF export has a Help & FAQ entry (#800)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HelpFaqScreen(
          showDeveloperFaq: false,
          showPortfolioHealthFaq: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('How do I export a Tax-Year PDF?', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('not tax advice', skipOffstage: false),
      findsOneWidget,
    );
  });
}
