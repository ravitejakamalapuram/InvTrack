import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

class _MockDataExportService extends Mock implements DataExportService {}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

// Exact copy the guest sign-out dialog must show (A05 / PLAT-01, UX-01).
const _linkGoogle = 'Link Google account';
const _exportBackup = 'Export backup';
const _signOutAndLoseData = 'Sign out and lose data';
const _genericMessage = 'Are you sure you want to sign out?';

void main() {
  late FakeAuthRepository authRepo;
  late _MockCrashlyticsService crashlytics;
  late _MockDataExportService exportService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    crashlytics = _MockCrashlyticsService();
    when(() => crashlytics.clearUserIdentifier()).thenAnswer((_) async {});
    exportService = _MockDataExportService();
    when(() => exportService.exportAndShare()).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(WidgetTester tester, UserEntity user) async {
    authRepo = FakeAuthRepository(user);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(_TestSecurityNotifier.new),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          crashlyticsServiceProvider.overrideWithValue(crashlytics),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          dataExportServiceProvider.overrideWithValue(exportService),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSignOutTile(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(SettingsNavTile, 'Sign Out'));
    await tester.pumpAndSettle();
  }

  group('Settings > Sign Out for a guest (anonymous) user', () {
    testWidgets(
      'shows a data-loss dialog whose primary action is Link Google account '
      'and secondary action is Export backup',
      (tester) async {
        await pumpSettings(tester, guestUser);
        await tapSignOutTile(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(_genericMessage), findsNothing);
        expect(
          find.text(
            'You are using a guest account. If you sign out, you cannot sign '
            'back in to it, and your investments, cash flows, goals and '
            'documents will be lost permanently.',
          ),
          findsOneWidget,
        );

        // Primary: the filled button links the guest account to Google.
        expect(find.widgetWithText(FilledButton, _linkGoogle), findsOneWidget);
        // Secondary: export a ZIP backup.
        expect(
          find.widgetWithText(OutlinedButton, _exportBackup),
          findsOneWidget,
        );
        // Destructive, last: plain sign-out spells out the consequence.
        expect(
          find.widgetWithText(TextButton, _signOutAndLoseData),
          findsOneWidget,
        );
        expect(authRepo.signOutCalls, 0);
      },
    );

    testWidgets('Sign out and lose data signs the guest out', (tester) async {
      await pumpSettings(tester, guestUser);
      await tapSignOutTile(tester);

      await tester.tap(find.text(_signOutAndLoseData));
      await tester.pumpAndSettle();

      expect(authRepo.signOutCalls, 1);
    });

    testWidgets('Export backup shares the ZIP and does not sign out', (
      tester,
    ) async {
      await pumpSettings(tester, guestUser);
      await tapSignOutTile(tester);

      await tester.tap(find.text(_exportBackup));
      await tester.pumpAndSettle();

      verify(() => exportService.exportAndShare()).called(1);
      expect(authRepo.signOutCalls, 0);
    });

    testWidgets('Link Google account starts linking and does not sign out', (
      tester,
    ) async {
      var linkCalls = 0;
      await pumpSettings(tester, guestUser);
      authRepo.onLinkAnonymousToGoogle = () async {
        linkCalls++;
        return googleUser.copyWithId(guestUser.id);
      };
      await tapSignOutTile(tester);

      await tester.tap(find.text(_linkGoogle));
      await tester.pumpAndSettle();

      expect(linkCalls, 1);
      expect(authRepo.signOutCalls, 0);
    });
  });

  group('Settings > Sign Out for a Google user', () {
    testWidgets('shows the normal confirmation dialog', (tester) async {
      await pumpSettings(tester, googleUser);
      await tapSignOutTile(tester);

      expect(find.text(_genericMessage), findsOneWidget);
      expect(find.text(_linkGoogle), findsNothing);
      expect(find.text(_exportBackup), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle();
      expect(authRepo.signOutCalls, 1);
    });
  });
}

extension on UserEntity {
  /// The same Google profile, as Firebase reports it after linking keeps the
  /// guest's UID.
  UserEntity copyWithId(String id) => UserEntity(
    id: id,
    email: email,
    displayName: displayName,
    photoUrl: photoUrl,
    isAnonymous: isAnonymous,
  );
}
