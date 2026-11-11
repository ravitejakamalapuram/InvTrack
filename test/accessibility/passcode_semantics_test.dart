// A49 (#806, UX-24): the lock screen tells a screen-reader user how many PIN
// digits are in (never which), announces its message, and still fits and
// keeps 48dp targets at 2.0x text on a 360x640 phone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Security extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(
    isBiometricEnabled: false,
    isBiometricAvailable: false,
  );
}

Future<void> _pump(WidgetTester tester, {double textScale = 1.0}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [securityProvider.overrideWith(_Security.new)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const PasscodeScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the PIN dots say how many digits are entered, not which', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(find.bySemanticsLabel('1 of 4 digits entered'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the lock screen message is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final message = tester.getSemantics(find.textContaining('Enter PIN'));
    expect(message.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('at 2.0x text on 360x640 nothing overflows and every target is '
      '48dp', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
