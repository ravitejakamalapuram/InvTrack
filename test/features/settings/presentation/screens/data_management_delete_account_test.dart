import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
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

class MockDataExportService extends Mock implements DataExportService {}

class FakeSharedPreferences extends Fake implements SharedPreferences {}

/// Guest backups kept on the device, by owner user id.
class FakeGuestBackupStore implements GuestBackupStore {
  final byOwner = <String, List<String>>{};

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) =>
      throw UnimplementedError();

  @override
  Future<String> transfer(String filePath, {required String toOwnerId}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> list({required String ownerId}) async =>
      List.of(byOwner[ownerId] ?? const []);

  @override
  Future<void> delete(String filePath) async {
    for (final files in byOwner.values) {
      files.remove(filePath);
    }
  }

  @override
  Future<void> deleteAll({required String ownerId}) async =>
      byOwner.remove(ownerId);
}

/// What the user is told whenever the request is on the server but the app
/// could not finish the deletion itself (A77).
const _scheduledText =
    'Your account is scheduled for deletion and will be fully deleted '
    'within 7 days. Some of your data may already be gone. To keep your '
    'account, sign in again within 24 hours and withdraw the request.';

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
  late MockDataExportService export;
  late FakeGuestBackupStore guestBackups;
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
    export = MockDataExportService();
    guestBackups = FakeGuestBackupStore();
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
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.confirmed);
    // No request yet, so the A88 banner stays hidden.
    when(
      () => requests.watchStatus(),
    ).thenAnswer((_) => Stream.value(DeletionRequestStatus.none));
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
    when(
      () => dataDeletion.deleteLocalData(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((_) async => calls.add('wipeLocal'));
    when(
      () => export.exportAndShare(),
    ).thenAnswer((_) async => calls.add('export'));
  });

  Future<AppLocalizations> pumpScreen(
    WidgetTester tester, {
    UserEntity signedInUser = user,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(signedInUser)),
          authRepositoryProvider.overrideWithValue(auth),
          googleSignInInitializedProvider.overrideWith(
            (ref) async => calls.add('init'),
          ),
          analyticsServiceProvider.overrideWithValue(analytics),
          sharedPreferencesProvider.overrideWithValue(prefs),
          deletionRequestServiceProvider.overrideWithValue(requests),
          accountDataDeletionServiceProvider.overrideWithValue(dataDeletion),
          documentStorageServiceProvider.overrideWithValue(documents),
          guestBackupStoreProvider.overrideWithValue(guestBackups),
          dataExportServiceProvider.overrideWithValue(export),
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
    expect(find.text(_scheduledText), findsOneWidget);
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
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.none);
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, ['init', 'reauth', 'request']);
    expect(
      find.text(
        "We couldn't file your deletion request, so nothing was deleted. "
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
    verifyNever(() => auth.signOut());
  });

  testWidgets('failed re-auth with the request still waiting on this device '
      'says it will be filed when back online and keeps the user signed in', (
    tester,
  ) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      throw AuthException(technicalMessage: 'GoogleSignInException: unknown');
    });
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return false;
    });
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.pending);
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, ['init', 'reauth', 'request']);
    verifyNever(() => auth.signOut());
    verifyNever(() => requests.withdraw());
    expect(
      find.text(
        'You seem to be offline. Your deletion request will be filed when '
        'you are back online, and your account and data are then deleted '
        'within 7 days. Nothing has been deleted yet.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('scheduled for deletion'), findsNothing);
  });

  testWidgets('guest: deletes the data and the anonymous user without asking '
      'for Google sign-in', (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      return true;
    });
    // Firebase lets an anonymous user delete itself.
    reauthenticated = true;
    final l10n = await pumpScreen(
      tester,
      signedInUser: const UserEntity(
        id: 'guest-1',
        email: '',
        isAnonymous: true,
      ),
    );

    await confirmDeletion(tester, l10n);

    expect(calls, ['request', 'wipe', 'deleteAuth', 'signOut']);
    verifyNever(() => auth.reauthenticateWithGoogle());
    expect(find.text('Account deleted successfully'), findsOneWidget);
  });

  // A05-F1: a guest backup kept after a partial merge holds the account's
  // investments and amounts, so deleting the account must remove it too.
  testWidgets("deleting the account removes that account's saved guest "
      "backups from the device, and no one else's", (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      reauthenticated = true;
      return true;
    });
    when(
      () => documents.deleteAllUserDocuments(),
    ).thenAnswer((_) async => calls.add('documents'));
    when(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((invocation) async {
      final deleteLocalFiles =
          invocation.namedArguments[#deleteLocalFiles]
              as Future<void> Function();
      await deleteLocalFiles();
      calls.add('wipe');
    });
    guestBackups.byOwner
      ..[user.id] = ['/files/guest_backups/uid-1/backup.zip']
      ..['uid-2'] = ['/files/guest_backups/uid-2/backup.zip'];
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    expect(calls, containsAllInOrder(['documents', 'wipe', 'deleteAuth']));
    expect(await guestBackups.list(ownerId: user.id), isEmpty);
    expect(await guestBackups.list(ownerId: 'uid-2'), hasLength(1));
    expect(find.text('Account deleted successfully'), findsOneWidget);
  });
  // A77: the request is on the server, so the job will delete the account.
  // Saying "your account is still active" would hide that from the user.
  testWidgets('a data wipe failing offline after the request was filed says '
      'the deletion is scheduled, never that the account is still active, '
      'and signs out', (tester) async {
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      reauthenticated = true;
      return true;
    });
    when(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((_) async {
      calls.add('wipe');
      throw NetworkException.noConnection();
    });
    final l10n = await pumpScreen(tester);

    await confirmDeletion(tester, l10n);

    // The request is filed, so this device's copy is not kept for a retry:
    // the server job cannot reach it.
    expect(calls, [
      'init',
      'reauth',
      'request',
      'wipe',
      'wipeLocal',
      'signOut',
    ]);
    verifyNever(() => auth.deleteAccount());
    verifyNever(() => requests.withdraw());
    verify(() => auth.signOut()).called(1);
    expect(find.text(_scheduledText), findsOneWidget);
    expect(find.textContaining('still active'), findsNothing);
  });

  group('A93: export a backup first', () {
    Finder inDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog), matching: finder);

    Future<void> openDeleteDialog(WidgetTester tester) async {
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
    }

    void expectNothingFiledOrDeleted() {
      verifyNever(() => requests.requestDeletion());
      verifyNever(
        () => dataDeletion.deleteEverything(
          deleteLocalFiles: any(named: 'deleteLocalFiles'),
          prefs: any(named: 'prefs'),
        ),
      );
      verifyNever(() => auth.deleteAccount());
    }

    testWidgets('the first dialog offers Cancel, Export a backup first and '
        'Delete Everything, and says what the backup leaves out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester);

      await openDeleteDialog(tester);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.actions, hasLength(3));
      expect(inDialog(find.text('Cancel')), findsOneWidget);
      expect(inDialog(find.text('Export a backup first')), findsOneWidget);
      expect(inDialog(find.text('Delete Everything')), findsOneWidget);
      expect(find.bySemanticsLabel('Export a backup first'), findsOneWidget);
      expect(
        inDialog(
          find.textContaining(
            'Some investment details, such as maturity dates and interest '
            'rates, are not in the backup yet.',
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('exporting shares a backup and keeps the dialog open without '
        'filing or deleting anything', (tester) async {
      await pumpScreen(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.text('Export a backup first'));
      await tester.pumpAndSettle();

      verify(() => export.exportAndShare()).called(1);
      expectNothingFiledOrDeleted();
      expect(inDialog(find.text('Delete Account')), findsOneWidget);
    });

    testWidgets('after exporting, Delete Everything still asks for the DELETE '
        'confirmation', (tester) async {
      final l10n = await pumpScreen(tester);
      await openDeleteDialog(tester);
      await tester.tap(find.text('Export a backup first'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.deleteEverything));
      await tester.pumpAndSettle();

      expect(find.text('Final Confirmation'), findsOneWidget);
      expectNothingFiledOrDeleted();
    });

    testWidgets('a failed export keeps the dialog open and files or deletes '
        'nothing', (tester) async {
      when(
        () => export.exportAndShare(),
      ).thenThrow(const FileSystemException('disk full'));
      await pumpScreen(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.text('Export a backup first'));
      await tester.pumpAndSettle();

      expect(inDialog(find.text('Delete Account')), findsOneWidget);
      expect(inDialog(find.text('Delete Everything')), findsOneWidget);
      expect(find.text('Failed to export data'), findsOneWidget);
      expectNothingFiledOrDeleted();
    });

    // share_plus reports its failures as PlatformException, which the
    // generic error mapping reads as a failed Google sign-in.
    testWidgets('a share sheet failure says the export failed, not that '
        'sign-in failed', (tester) async {
      when(() => export.exportAndShare()).thenThrow(
        PlatformException(code: 'error', message: 'Share callback error'),
      );
      await pumpScreen(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.text('Export a backup first'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to export data'), findsOneWidget);
      expect(find.textContaining('Sign in failed'), findsNothing);
      expect(inDialog(find.text('Delete Everything')), findsOneWidget);
      expectNothingFiledOrDeleted();
    });
  });
}
