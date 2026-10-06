import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_guest_merge.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _FakeAuthCredential extends Fake implements AuthCredential {}

_MockUser _firebaseUser(String uid, {required bool anonymous}) {
  final user = _MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.isAnonymous).thenReturn(anonymous);
  when(() => user.email).thenReturn(anonymous ? null : 'existing@example.com');
  when(() => user.displayName).thenReturn(null);
  when(() => user.photoURL).thenReturn(null);
  return user;
}

/// A guest (`guest1`) tries to link a Google account that already exists
/// (`google1`), then chooses backup and merge. Real [FirebaseAuthRepository]
/// over mocked Firebase Auth and Google Sign-In, so the test counts how
/// often the Google account picker ([GoogleSignIn.authenticate]) opens.
void main() {
  late _MockFirebaseAuth firebaseAuth;
  late _MockGoogleSignIn googleSignIn;
  late _MockUser guest;
  late _MockUser google;
  late User? current;
  late StreamController<User?> userChanges;
  late List<String> calls;
  late InMemoryGuestBackupStore store;
  late RecordingGuestImportService importer;
  late FirebaseAuthRepository repository;
  late ProviderContainer container;

  /// Credentials passed to [FirebaseAuth.signInWithCredential], in order.
  late List<AuthCredential> signInCredentials;

  /// Backups the guest owned when each sign-in started.
  late List<int> guestBackupsAtSignIn;

  /// What each [FirebaseAuth.signInWithCredential] call does, in order;
  /// later calls repeat the last entry.
  late List<Object?> signInErrors;

  setUpAll(() => registerFallbackValue(_FakeAuthCredential()));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    firebaseAuth = _MockFirebaseAuth();
    googleSignIn = _MockGoogleSignIn();
    guest = _firebaseUser('guest1', anonymous: true);
    google = _firebaseUser('google1', anonymous: false);
    current = guest;
    userChanges = StreamController<User?>.broadcast();
    calls = [];
    signInCredentials = [];
    guestBackupsAtSignIn = [];
    signInErrors = [null];
    store = InMemoryGuestBackupStore(calls: calls);
    importer = RecordingGuestImportService();

    final account = _MockGoogleSignInAccount();
    final authentication = _MockGoogleSignInAuthentication();
    when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
    when(() => googleSignIn.signOut()).thenAnswer((_) async {});
    when(() => account.id).thenReturn('google-account');
    when(() => account.email).thenReturn('existing@example.com');
    when(() => account.authentication).thenReturn(authentication);
    when(() => authentication.idToken).thenReturn('id-token-1');

    when(() => firebaseAuth.currentUser).thenAnswer((_) => current);
    when(() => firebaseAuth.userChanges()).thenAnswer((_) async* {
      yield current;
      yield* userChanges.stream;
    });
    // The Google account already exists, so linking it to the guest fails.
    when(
      () => guest.linkWithCredential(any()),
    ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
    when(() => firebaseAuth.signInWithCredential(any())).thenAnswer((
      invocation,
    ) async {
      calls.add('signInWithCredential');
      signInCredentials.add(invocation.positionalArguments.single);
      guestBackupsAtSignIn.add((await store.list(ownerId: 'guest1')).length);
      final error =
          signInErrors[(signInCredentials.length - 1).clamp(
            0,
            signInErrors.length - 1,
          )];
      if (error != null) throw error;
      current = google;
      userChanges.add(google);
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(google);
      return credential;
    });

    repository = FirebaseAuthRepository(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        dataExportServiceProvider.overrideWith(
          (ref) => FakeGuestExportService(),
        ),
        guestBackupStoreProvider.overrideWithValue(store),
        dataImportServiceProvider.overrideWith((ref) {
          final user = ref.watch(authStateProvider).value;
          return user?.id == 'google1' ? importer : null;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await userChanges.close();
    });
    // The app is running as the guest.
    container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);
  });

  Future<void> linkFailsBecauseTheAccountExists() async {
    await expectLater(
      repository.linkAnonymousToGoogle(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthExceptionCode.credentialAlreadyInUse,
        ),
      ),
    );
  }

  Future<GuestMergeOutcome> backupAndSignIn() => container
      .read(guestBackupMergeServiceProvider)
      .backupAndSignIn(confirmDetailsNotMoved: (_) async => true);

  test('the merge signs in with the credential from the failed link, so the '
      'Google account picker opens once', () async {
    await linkFailsBecauseTheAccountExists();
    final linked =
        verify(() => guest.linkWithCredential(captureAny())).captured.single
            as AuthCredential;

    final outcome = await backupAndSignIn();

    expect(outcome, isA<GuestMergeSucceeded>());
    verify(() => googleSignIn.authenticate()).called(1);
    expect(signInCredentials, hasLength(1));
    expect(signInCredentials.single, same(linked));
    // The backup is on disk before the session switch.
    expect(calls, ['save', 'signInWithCredential']);
    expect(importer.calls, hasLength(1));
    expect(container.read(authStateProvider).value?.id, 'google1');
  });

  test('a rejected credential falls back to the account picker once and '
      'keeps the backup', () async {
    signInErrors = [FirebaseAuthException(code: 'invalid-credential'), null];
    await linkFailsBecauseTheAccountExists();

    final outcome = await backupAndSignIn();

    expect(outcome, isA<GuestMergeSucceeded>());
    // Once to link, once more for the fallback sign-in.
    verify(() => googleSignIn.authenticate()).called(2);
    expect(signInCredentials, hasLength(2));
    // The backup was still saved when the fallback sign-in ran.
    expect(guestBackupsAtSignIn, [1, 1]);
    expect(calls, ['save', 'signInWithCredential', 'signInWithCredential']);
    expect(importer.calls, hasLength(1));
    expect(container.read(authStateProvider).value?.id, 'google1');
  });

  test('without a failed link, the merge opens the account picker once, as '
      'before', () async {
    final outcome = await backupAndSignIn();

    expect(outcome, isA<GuestMergeSucceeded>());
    verify(() => googleSignIn.authenticate()).called(1);
    expect(calls, ['save', 'signInWithCredential']);
  });

  test('a failed sign-in with the kept credential that is not a rejection '
      'is reported, not retried with the account picker', () async {
    signInErrors = [FirebaseAuthException(code: 'network-request-failed')];
    await linkFailsBecauseTheAccountExists();

    await expectLater(
      backupAndSignIn(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthExceptionCode.signInFailed,
        ),
      ),
    );
    verify(() => googleSignIn.authenticate()).called(1);
    // The guest is still signed in with all of their data, so the backup is
    // redundant.
    expect(current, same(guest));
    expect(store.files, isEmpty);
  });

  test('the kept credential is used at most once', () async {
    await linkFailsBecauseTheAccountExists();

    expect((await repository.signInWithLinkCredential())?.id, 'google1');
    expect(await repository.signInWithLinkCredential(), isNull);
    expect(signInCredentials, hasLength(1));
  });

  test('signing out drops the kept credential', () async {
    when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
    await linkFailsBecauseTheAccountExists();

    await repository.signOut();

    expect(await repository.signInWithLinkCredential(), isNull);
    expect(signInCredentials, isEmpty);
  });

  test('deleting the account drops the kept credential', () async {
    when(() => guest.delete()).thenAnswer((_) async {});
    await linkFailsBecauseTheAccountExists();

    await repository.deleteAccount();

    expect(await repository.signInWithLinkCredential(), isNull);
    expect(signInCredentials, isEmpty);
  });
}
