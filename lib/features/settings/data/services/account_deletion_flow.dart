import 'package:firebase_auth/firebase_auth.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';

/// What happened when the user asked to delete their account.
enum AccountDeletionOutcome {
  /// Data and the Auth user are gone.
  deleted,

  /// The user cancelled re-authentication. Nothing was deleted or filed.
  cancelled,

  /// Re-authentication failed or was cancelled after the data was wiped. A
  /// `deletionRequests/{uid}` request is filed and kept, so the server job
  /// finishes the deletion.
  scheduled,

  /// Re-authentication failed and the request could not be filed (e.g.
  /// offline). Nothing was deleted.
  notDeleted,
}

/// Runs Delete Account for a signed-in (non-guest) user in a safe order.
///
/// Firebase refuses to delete an Auth user whose sign-in is not recent, so a
/// stale session is re-authenticated FIRST: a cancel then deletes nothing.
/// Only after that is the server-side request filed, the data wiped and the
/// Auth user deleted. Every path that gives up after filing keeps the request
/// so the scheduled job completes the deletion.
class AccountDeletionFlow {
  AccountDeletionFlow({
    required AuthRepository auth,
    required DeletionRequestService requests,
    required Future<void> Function() prepareGoogleSignIn,
    required Future<void> Function() deleteUserData,
    DateTime Function() now = DateTime.now,
  }) : _auth = auth,
       _requests = requests,
       _prepareGoogleSignIn = prepareGoogleSignIn,
       _deleteUserData = deleteUserData,
       _now = now;

  /// Firebase's recent-login window is about 5 minutes; stay inside it.
  static const recentLoginWindow = Duration(minutes: 4);

  final AuthRepository _auth;
  final DeletionRequestService _requests;
  final Future<void> Function() _prepareGoogleSignIn;
  final Future<void> Function() _deleteUserData;
  final DateTime Function() _now;

  Future<AccountDeletionOutcome> run() async {
    if (_sessionIsStale) {
      switch (await _reauthenticate()) {
        case _Reauth.cancelled:
          return AccountDeletionOutcome.cancelled;
        case _Reauth.failed:
          return _scheduleOnServer();
        case _Reauth.succeeded:
          break;
      }
    }

    // File the request before the client wipe (APP-334): if anything below
    // fails, the job finishes the deletion.
    await _requests.requestDeletion();
    await _deleteUserData();

    try {
      await _auth.deleteAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      // The data is already gone: keep the request whatever happens here.
      if (await _reauthenticate() != _Reauth.succeeded) {
        return AccountDeletionOutcome.scheduled;
      }
      await _auth.deleteAccount();
    }
    return AccountDeletionOutcome.deleted;
  }

  bool get _sessionIsStale {
    final lastSignIn = _auth.lastSignInTime;
    return lastSignIn == null ||
        _now().difference(lastSignIn) > recentLoginWindow;
  }

  Future<_Reauth> _reauthenticate() async {
    try {
      // google_sign_in v7 must be initialised (with serverClientId on
      // Android) before authenticate(); a returning user never passed
      // through the sign-in screen that does it.
      await _prepareGoogleSignIn();
      return await _auth.reauthenticateWithGoogle()
          ? _Reauth.succeeded
          : _Reauth.cancelled;
    } catch (e, st) {
      LoggerService.error(
        'Re-authentication for account deletion failed',
        error: e,
        stackTrace: st,
      );
      return _Reauth.failed;
    }
  }

  /// The user confirmed twice, but we could not prove a recent login. Leave
  /// the deletion to the server job (it also deletes the Auth user).
  Future<AccountDeletionOutcome> _scheduleOnServer() async {
    final filed =
        await _requests.requestDeletion() || await _requests.hasRequest();
    return filed
        ? AccountDeletionOutcome.scheduled
        : AccountDeletionOutcome.notDeleted;
  }
}

enum _Reauth { succeeded, cancelled, failed }
