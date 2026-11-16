// #936: the Help & FAQ explains custom types for Other investments.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/screens/help_faq_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

const _question = 'Can I give an Other investment a more specific type?';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

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

  testWidgets('the custom types question and answer are shown', (tester) async {
    await tester.pumpWidget(_app(const HelpFaqScreen(showDeveloperFaq: false)));
    await tester.pumpAndSettle();

    expect(find.text(_question, skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining(
        'does not change how the investment is calculated',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });
}
