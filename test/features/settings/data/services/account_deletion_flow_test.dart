import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/settings/data/services/account_deletion_flow.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);

  late MockAuthRepository auth;
  late MockDeletionRequestService requests;
  late List<String> calls;
  late bool reauthenticated;
  late bool sessionFresh;
  late Future<void> Function() prepareGoogleSignIn;
  late Future<void> Function() deleteUserData;

  AccountDeletionFlow flow({bool isAnonymous = false}) => AccountDeletionFlow(
    auth: auth,
    isAnonymous: isAnonymous,
    requests: requests,
    prepareGoogleSignIn: prepareGoogleSignIn,
    deleteUserData: deleteUserData,
    now: () => now,
  );

  void signedInAgo(Duration? age) => when(
    () => auth.lastSignInTime,
  ).thenReturn(age == null ? null : now.subtract(age));

  void reauthReturns(bool result) =>
      when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
        calls.add('reauth');
        reauthenticated = result;
        return result;
      });

  void reauthThrows() =>
      when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
        calls.add('reauth');
        throw AuthException(technicalMessage: 'GoogleSignInException');
      });

  setUp(() {
    auth = MockAuthRepository();
    requests = MockDeletionRequestService();
    calls = [];
    reauthenticated = false;
    sessionFresh = false;
    prepareGoogleSignIn = () async => calls.add('init');
    deleteUserData = () async => calls.add('wipe');

    // Firebase refuses to delete the Auth user until the sign-in is recent.
    when(() => auth.deleteAccount()).thenAnswer((_) async {
      calls.add('deleteAuth');
      if (!reauthenticated && !sessionFresh) {
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
    when(() => requests.withdraw()).thenAnswer((_) async {
      calls.add('withdraw');
      return true;
    });
  });

  group('stale session (signed in more than 4 minutes ago)', () {
    setUp(() => signedInAgo(const Duration(minutes: 4, seconds: 1)));

    test('initialises Google Sign-In and re-authenticates before filing the '
        'request, wiping data and deleting the Auth user', () async {
      reauthReturns(true);

      expect(await flow().run(), AccountDeletionOutcome.deleted);
      expect(calls, ['init', 'reauth', 'request', 'wipe', 'deleteAuth']);
    });

    test('cancelled re-auth deletes nothing and files nothing', () async {
      reauthReturns(false);

      expect(await flow().run(), AccountDeletionOutcome.cancelled);
      expect(calls, ['init', 'reauth']);
      verifyNever(() => requests.requestDeletion());
      verifyNever(() => auth.deleteAccount());
    });

    test('failed re-auth files the request for the server job, deletes '
        'nothing on the device and never withdraws it', () async {
      reauthThrows();

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, ['init', 'reauth', 'request']);
      verifyNever(() => requests.withdraw());
    });

    test(
      'Google Sign-In that cannot initialise counts as a failed re-auth',
      () async {
        reauthReturns(true);
        prepareGoogleSignIn = () async {
          calls.add('init');
          throw StateError('serverClientId must be provided on Android');
        };

        expect(await flow().run(), AccountDeletionOutcome.scheduled);
        expect(calls, ['init', 'request']);
        verifyNever(() => auth.reauthenticateWithGoogle());
      },
    );

    test('failed re-auth with a request that already exists (e.g. from the '
        'web) is still scheduled', () async {
      reauthThrows();
      when(() => requests.requestDeletion()).thenAnswer((_) async {
        calls.add('request');
        return false;
      });
      when(
        () => requests.requestStatus(),
      ).thenAnswer((_) async => DeletionRequestStatus.confirmed);

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
    });

    test(
      'failed re-auth when the request cannot be filed deletes nothing',
      () async {
        reauthThrows();
        when(() => requests.requestDeletion()).thenAnswer((_) async {
          calls.add('request');
          return false;
        });
        when(
          () => requests.requestStatus(),
        ).thenAnswer((_) async => DeletionRequestStatus.none);

        expect(await flow().run(), AccountDeletionOutcome.notDeleted);
        expect(calls, ['init', 'reauth', 'request']);
      },
    );

    test('failed re-auth with a request still waiting on this device (offline '
        'or the write timed out) is queued, never scheduled', () async {
      reauthThrows();
      when(() => requests.requestDeletion()).thenAnswer((_) async {
        calls.add('request');
        return false;
      });
      when(
        () => requests.requestStatus(),
      ).thenAnswer((_) async => DeletionRequestStatus.pending);

      expect(await flow().run(), AccountDeletionOutcome.queued);
      expect(calls, ['init', 'reauth', 'request']);
      verifyNever(() => requests.withdraw());
    });
  });

  test('unknown sign-in time is treated as stale', () async {
    signedInAgo(null);
    reauthReturns(true);

    expect(await flow().run(), AccountDeletionOutcome.deleted);
    expect(calls.take(2), ['init', 'reauth']);
  });

  group('recent session (signed in 3 min 59 s ago)', () {
    setUp(() => signedInAgo(const Duration(minutes: 3, seconds: 59)));

    test('deletes without asking the user to sign in again', () async {
      sessionFresh = true;

      expect(await flow().run(), AccountDeletionOutcome.deleted);
      expect(calls, ['request', 'wipe', 'deleteAuth']);
      verifyNever(() => auth.reauthenticateWithGoogle());
    });

    test('Firebase still asking for a recent login: re-auth (after init) '
        'then delete the Auth user', () async {
      reauthReturns(true);

      expect(await flow().run(), AccountDeletionOutcome.deleted);
      expect(calls, [
        'request',
        'wipe',
        'deleteAuth',
        'init',
        'reauth',
        'deleteAuth',
      ]);
    });

    test('re-auth cancelled after the wipe keeps the request so the job '
        'removes the Auth user', () async {
      reauthReturns(false);

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, ['request', 'wipe', 'deleteAuth', 'init', 'reauth']);
      verifyNever(() => requests.withdraw());
    });

    test('a request that never reached the server stops the deletion before '
        'any data is wiped', () async {
      sessionFresh = true;
      when(() => requests.requestDeletion()).thenAnswer((_) async {
        calls.add('request');
        return false;
      });
      when(
        () => requests.requestStatus(),
      ).thenAnswer((_) async => DeletionRequestStatus.none);

      expect(await flow().run(), AccountDeletionOutcome.notDeleted);
      expect(calls, ['request']);
      verifyNever(() => auth.deleteAccount());
    });

    test('a request that never reached the server is never reported as '
        'scheduled when Firebase then asks for a recent login', () async {
      reauthReturns(false);
      when(() => requests.requestDeletion()).thenAnswer((_) async {
        calls.add('request');
        return false;
      });
      when(
        () => requests.requestStatus(),
      ).thenAnswer((_) async => DeletionRequestStatus.none);

      expect(await flow().run(), AccountDeletionOutcome.notDeleted);
      expect(calls, ['request']);
    });

    test('a request still waiting on this device is queued and nothing is '
        'wiped', () async {
      sessionFresh = true;
      when(() => requests.requestDeletion()).thenAnswer((_) async {
        calls.add('request');
        return false;
      });
      when(
        () => requests.requestStatus(),
      ).thenAnswer((_) async => DeletionRequestStatus.pending);

      expect(await flow().run(), AccountDeletionOutcome.queued);
      expect(calls, ['request']);
      verifyNever(() => auth.deleteAccount());
    });

    test('re-auth failing after the wipe keeps the request', () async {
      reauthThrows();

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      verifyNever(() => requests.withdraw());
    });

    // A77: once the server holds the request, the job finishes the deletion
    // whatever fails here, so the user must be told it is scheduled (and
    // signed out), never that the account is still active.
    test('a data wipe failing offline after the request was filed keeps the '
        'request and reports the deletion as scheduled', () async {
      deleteUserData = () async {
        calls.add('wipe');
        throw NetworkException.noConnection();
      };

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, ['request', 'wipe']);
      verifyNever(() => requests.withdraw());
      verifyNever(() => auth.deleteAccount());
    });

    test('any other wipe failure after the request was filed is also '
        'scheduled', () async {
      deleteUserData = () async {
        calls.add('wipe');
        throw StateError('x');
      };

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, ['request', 'wipe']);
      verifyNever(() => requests.withdraw());
      verifyNever(() => auth.deleteAccount());
    });

    test('a network failure deleting the Auth user after the wipe keeps the '
        'request and reports the deletion as scheduled', () async {
      when(() => auth.deleteAccount()).thenAnswer((_) async {
        calls.add('deleteAuth');
        throw FirebaseAuthException(code: 'network-request-failed');
      });

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, ['request', 'wipe', 'deleteAuth']);
      verifyNever(() => requests.withdraw());
    });

    test('a failure deleting the Auth user after a successful re-auth keeps '
        'the request and reports the deletion as scheduled', () async {
      reauthReturns(true);
      var attempts = 0;
      when(() => auth.deleteAccount()).thenAnswer((_) async {
        calls.add('deleteAuth');
        attempts++;
        throw FirebaseAuthException(
          code: attempts == 1
              ? 'requires-recent-login'
              : 'network-request-failed',
        );
      });

      expect(await flow().run(), AccountDeletionOutcome.scheduled);
      expect(calls, [
        'request',
        'wipe',
        'deleteAuth',
        'init',
        'reauth',
        'deleteAuth',
      ]);
      verifyNever(() => requests.withdraw());
    });
  });

  group('guest (anonymous) user with a stale session', () {
    // A guest's last sign-in is when they first opened the app, and they have
    // no Google account to re-authenticate with.
    setUp(() => signedInAgo(const Duration(days: 30)));

    test('files the request, wipes the data and deletes the Auth user '
        'without asking for Google sign-in', () async {
      sessionFresh = true;
      reauthReturns(true);

      expect(
        await flow(isAnonymous: true).run(),
        AccountDeletionOutcome.deleted,
      );
      expect(calls, ['request', 'wipe', 'deleteAuth']);
      verifyNever(() => auth.reauthenticateWithGoogle());
    });

    test('Firebase asking for a recent login after the wipe keeps the '
        'request for the server job and never offers Google sign-in', () async {
      reauthReturns(true);

      expect(
        await flow(isAnonymous: true).run(),
        AccountDeletionOutcome.scheduled,
      );
      expect(calls, ['request', 'wipe', 'deleteAuth']);
      verifyNever(() => auth.reauthenticateWithGoogle());
      verifyNever(() => requests.withdraw());
    });
  });
}
