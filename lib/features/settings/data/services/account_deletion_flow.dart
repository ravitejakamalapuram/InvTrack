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

  /// The server holds a `deletionRequests/{uid}` request, but the app did not
  /// finish the deletion itself: re-authentication failed or was cancelled,
  /// or wiping the data or deleting the Auth user failed (e.g. offline). The
  /// request is kept, so the server job finishes the deletion.
  scheduled,

  /// The request could not be filed (e.g. offline, or rejected). Nothing was
  /// deleted.
  notDeleted,

  /// The request is saved on this device but the server has not confirmed
  /// it (offline, or the write timed out). Nothing was deleted; the request
  /// is sent once the device is back online, so the user stays signed in.
  queued,
}

/// Runs Delete Account in a safe order.
///
/// Firebase refuses to delete an Auth user whose sign-in is not recent, so a
/// stale session is re-authenticated FIRST: a cancel then deletes nothing.
/// Only after that is the server-side request filed, the data wiped and the
/// Auth user deleted. Nothing is wiped, and nothing is reported as scheduled,
/// until the server has confirmed the request. Every path that gives up after
/// filing, including a failed wipe, keeps the request and reports
/// [AccountDeletionOutcome.scheduled], because the job will complete the
/// deletion whatever the app says. When the wipe itself fails, this device's
/// copy is still removed ([deleteLocalData]), since the job cannot reach it
/// and the user is signed out next. A guest ([isAnonymous]) is
/// never sent to Google re-auth: the request is filed, the data wiped and the
/// anonymous user deleted, or left to the job if Firebase refuses.
class AccountDeletionFlow {
  AccountDeletionFlow({
    required AuthRepository auth,
    required bool isAnonymous,
    required DeletionRequestService requests,
    required Future<void> Function() prepareGoogleSignIn,
    required Future<void> Function() deleteUserData,
    required Future<void> Function() deleteLocalData,
    DateTime Function() now = DateTime.now,
  }) : _auth = auth,
       _isAnonymous = isAnonymous,
       _requests = requests,
       _prepareGoogleSignIn = prepareGoogleSignIn,
       _deleteUserData = deleteUserData,
       _deleteLocalData = deleteLocalData,
       _now = now;

  /// Firebase's recent-login window is about 5 minutes; stay inside it.
  static const recentLoginWindow = Duration(minutes: 4);

  final AuthRepository _auth;
  final bool _isAnonymous;
  final DeletionRequestService _requests;
  final Future<void> Function() _prepareGoogleSignIn;
  final Future<void> Function() _deleteUserData;
  final Future<void> Function() _deleteLocalData;
  final DateTime Function() _now;

  Future<AccountDeletionOutcome> run() async {
    // A guest has no Google account to re-authenticate with, and calling
    // Google re-auth on an anonymous user always fails.
    if (!_isAnonymous && _sessionIsStale) {
      switch (await _reauthenticate()) {
        case _Reauth.cancelled:
          return AccountDeletionOutcome.cancelled;
        case _Reauth.failed:
          // The user confirmed twice, but we could not prove a recent login.
          // Leave the deletion to the server job (it also deletes the Auth
          // user).
          return _fileRequest();
        case _Reauth.succeeded:
          break;
      }
    }

    // File the request before the client wipe (APP-334): if anything below
    // fails, the job finishes the deletion. Without a request the server
    // holds, that promise cannot be kept, so wipe nothing.
    final filed = await _fileRequest();
    if (filed != AccountDeletionOutcome.scheduled) return filed;

    // From here the server holds the request and the job will delete the
    // account whatever fails, so a failure must never read as "still active".
    try {
      await _deleteUserData();
    } catch (e) {
      _leftToJob(e);
      // Nothing is kept for a retry any more, and the job cannot reach this
      // device: remove its copy now, as far as possible.
      try {
        await _deleteLocalData();
      } catch (e) {
        LoggerService.warn(
          'Local data cleanup after a failed wipe did not finish',
          metadata: {'errorType': e.runtimeType.toString()},
        );
      }
      return AccountDeletionOutcome.scheduled;
    }
    try {
      return await _deleteAuthUser();
    } catch (e) {
      _leftToJob(e);
      return AccountDeletionOutcome.scheduled;
    }
  }

  /// Logs the error type only: a wipe error can carry a device path, and an
  /// Auth error an email (rule 7).
  void _leftToJob(Object e) => LoggerService.warn(
    'Account deletion left to the server job',
    metadata: {'errorType': e.runtimeType.toString()},
  );

  Future<AccountDeletionOutcome> _deleteAuthUser() async {
    try {
      await _auth.deleteAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      if (_isAnonymous || await _reauthenticate() != _Reauth.succeeded) {
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

  /// Files the request and reports [AccountDeletionOutcome.scheduled] only
  /// when the server holds it (written now, or already there, e.g. from the
  /// web).
  Future<AccountDeletionOutcome> _fileRequest() async {
    if (await _requests.requestDeletion()) {
      return AccountDeletionOutcome.scheduled;
    }
    return switch (await _requests.requestStatus()) {
      DeletionRequestStatus.confirmed => AccountDeletionOutcome.scheduled,
      DeletionRequestStatus.pending => AccountDeletionOutcome.queued,
      DeletionRequestStatus.none => AccountDeletionOutcome.notDeleted,
    };
  }
}

enum _Reauth { succeeded, cancelled, failed }
