import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

class MockAccountDataDeletionService extends Mock
    implements AccountDataDeletionService {}

class MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class FakeSharedPreferences extends Fake implements SharedPreferences {}

/// Delete Account flow on the Data & Account screen for a Google user whose
/// sign-in is older than Firebase's recent-login window (the normal case for
/// a returning user). Every side effect is recorded in [calls] so the tests
/// can assert the exact order.
void main() {
  const user = UserEntity(id: 'uid-1', email: 'user@example.com');

  late MockAuthRepository auth;
  late MockAnalyticsService analytics;
  late MockDeletionRequestService requests;
  late MockAccountDataDeletionService dataDeletion;
  late MockDocumentStorageService documents;
  late SharedPreferences prefs;
  late List<String> calls;
  late bool reauthenticated;

  setUpAll(() {
    registerFallbackValue(() async {});
    registerFallbackValue(FakeSharedPreferences());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = MockAuthRepository();
    analytics = MockAnalyticsService();
    requests = MockDeletionRequestService();
    dataDeletion = MockAccountDataDeletionService();
    documents = MockDocumentStorageService();
    calls = [];
    reauthenticated = false;

    when(() => analytics.setUserId(any())).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async => calls.add('signOut'));
    // A stale session: Firebase refuses to delete the Auth user until the
    // user has re-authenticated.
    when(() => auth.deleteAccount()).thenAnswer((_) async {
      calls.add('deleteAuth');
      if (!reauthenticated) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
    });
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return true;
    });
    when(() => requests.hasRequest()).thenAnswer((_) async => true);
    when(() => requests.withdraw()).thenAnswer((_) async {
      calls.add('withdraw');
      return true;
    });
    when(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((_) async => calls.add('wipe'));
  });

  Future<AppLocalizations> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          authRepositoryProvider.overrideWithValue(auth),
          googleSignInInitializedProvider.overrideWith(
            (ref) async => calls.add('init'),
          ),
          analyticsServiceProvider.overrideWithValue(analytics),
          sharedPreferencesProvider.overrideWithValue(prefs),
          deletionRequestServiceProvider.overrideWithValue(requests),
          accountDataDeletionServiceProvider.overrideWithValue(dataDeletion),
          documentStorageServiceProvider.overrideWithValue(documents),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(DataManagementScreen)),
    );
  }

  Future<void> confirmDeletion(
    WidgetTester tester,
    AppLocalizations l10n,
  ) async {
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteEverything));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.text(l10n.deleteMyAccount));
    await tester.pumpAndSettle();
  }

  testWidgets('stale session: Google Sign-In is initialised and the user '
      're-authenticated before any request is filed or data deleted', (
    tester,
  ) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      reauthenticated = true;
      return true;
    });
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, [
      'init',
      'reauth',
      'request',
      'wipe',
      'deleteAuth',
      'signOut',
    ]);
    expect(find.text('Account deleted successfully'), findsOneWidget);
  });

  testWidgets('cancelled re-auth deletes nothing, files nothing and says '
      'nothing was deleted', (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      return false;
    });
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, ['init', 'reauth']);
    verifyNever(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    );
    expect(
      find.text('Account deletion cancelled. Nothing was deleted.'),
      findsOneWidget,
    );
  });

  testWidgets('failed re-auth files the request, keeps it for the server job '
      'and says deletion is scheduled', (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      throw AuthException(technicalMessage: 'GoogleSignInException: unknown');
    });
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, ['init', 'reauth', 'request', 'signOut']);
    verifyNever(() => requests.withdraw());
    expect(
      find.text(
        "We couldn't confirm your sign-in, so your account and data are "
        'scheduled for deletion. This finishes within 7 days.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed re-auth with no way to file the request deletes nothing '
      'and says so', (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      throw AuthException(technicalMessage: 'GoogleSignInException: unknown');
    });
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return false;
    });
    when(() => requests.hasRequest()).thenAnswer((_) async => false);
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, ['init', 'reauth', 'request']);
    expect(
      find.text(
        "We couldn't confirm your sign-in, so nothing was deleted. "
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });
}
