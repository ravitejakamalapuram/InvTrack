import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

// A69 (C074, SEC-05): the operator can read data stored in Firebase, so the
// notice must say so instead of promising a private cloud.
const _dataNotice =
    'The app lock protects access to InvTrack on this device. Your data is '
    "stored in InvTrack's Google Firebase project under your account, with "
    'an offline copy on this device so InvTrack keeps working without a '
    'connection. In the app, only your signed-in account can see it. The '
    'developer can technically access stored data and does so only to '
    'handle your support or deletion requests, or when the law requires it.';

void main() {
  testWidgets('Security settings shows the accurate data notice', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [securityProvider.overrideWith(_TestSecurityNotifier.new)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SecuritySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_dataNotice), findsOneWidget);
    expect(find.bySemanticsLabel(_dataNotice), findsOneWidget);
    expect(find.textContaining('private cloud'), findsNothing);
    semantics.dispose();
  });
}
