import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Where a `deletionRequests/{uid}` document stands, as far as this device can
/// tell.
enum DeletionRequestStatus {
  /// The server holds the request: the deletion job will act on it.
  confirmed,

  /// The request is only in this device's Firestore cache (offline, or the
  /// write has not been acknowledged yet). It is sent when the device is back
  /// online and this user is signed in.
  pending,

  /// No request was found.
  none,
}

/// Reads, files and withdraws the account-deletion request document
/// `deletionRequests/{uid}`.
///
/// The same queue is used by the web request page. A daily server job deletes
/// the account once the request is older than the 24 hour withdrawal window,
/// which also finishes deletions the app could not complete itself (offline,
/// failed re-auth). The app only withdraws from the sign-in notice or the
/// pending-request banner; a cancelled re-auth happens before anything is
/// filed.
///
/// Security rules only allow the owner to `get`, `create` (exactly
/// requestedAt = server time, source, version) and `delete` the document.
class DeletionRequestService {
  DeletionRequestService({
    required FirebaseFirestore firestore,
    required String userId,
    this.timeout = const Duration(seconds: 8),
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  /// Bounds every call so a flaky connection cannot stall the delete flow.
  final Duration timeout;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('deletionRequests').doc(_userId);

  /// Returns true when a request exists for this user. Fails soft (returns
  /// false) when it cannot be read, e.g. offline.
  Future<bool> hasRequest() async {
    try {
      final snap = await _doc.get().timeout(timeout);
      return snap.exists;
    } catch (e, st) {
      LoggerService.warn(
        'Could not read deletion request',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Asks the server whether the request exists. A cached document, or one
  /// with a local write the server has not acknowledged, is only [pending]:
  /// Firestore resolves offline writes locally, so a default read would
  /// report a request the server has never seen. Never throws.
  Future<DeletionRequestStatus> requestStatus() async {
    try {
      final snap = await _doc
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      if (snap.exists && !snap.metadata.hasPendingWrites) {
        return DeletionRequestStatus.confirmed;
      }
    } catch (e, st) {
      LoggerService.warn(
        'Could not confirm deletion request',
        error: e,
        stackTrace: st,
      );
    }
    return await hasRequest()
        ? DeletionRequestStatus.pending
        : DeletionRequestStatus.none;
  }

  /// Follows the request live. Metadata changes are included, so a request
  /// saved offline moves from [DeletionRequestStatus.pending] to
  /// [DeletionRequestStatus.confirmed] once the server acknowledges it.
  /// A withdrawal reads as [DeletionRequestStatus.none] as soon as it is
  /// issued, even offline (see [pendingWritesSent]). Listen errors are passed
  /// on.
  Stream<DeletionRequestStatus> watchStatus() => _doc
      .snapshots(includeMetadataChanges: true)
      .map(
        (snap) => !snap.exists
            ? DeletionRequestStatus.none
            : snap.metadata.hasPendingWrites
            ? DeletionRequestStatus.pending
            : DeletionRequestStatus.confirmed,
      );

  /// Completes with true once the server has acknowledged every write
  /// queued on this device, such as a [withdraw] that timed out. Firestore
  /// drops a deleted document from [watchStatus] as soon as the delete is
  /// issued and does not flag it as a pending write, so this is the only
  /// sign that a queued withdrawal reached the server. False if Firestore
  /// stops waiting (e.g. the user changed). Never throws; no timeout.
  Future<bool> pendingWritesSent() async {
    try {
      await _firestore.waitForPendingWrites();
      return true;
    } catch (e) {
      LoggerService.warn(
        'Stopped waiting for queued writes',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Files a request with source `app`. Returns true only when THIS call
  /// created it and the server acknowledged the write, so the caller knows
  /// whether it may withdraw it later (an existing request, e.g. from the
  /// web, must be left alone). Never throws: on false, use [requestStatus]
  /// to learn whether a request reached the server.
  Future<bool> requestDeletion() async {
    try {
      if ((await _doc.get().timeout(timeout)).exists) return false;
      await _doc
          .set({
            'requestedAt': FieldValue.serverTimestamp(),
            'source': 'app',
            'version': 1,
          })
          .timeout(timeout);
      return true;
    } catch (e, st) {
      LoggerService.warn(
        'Could not file deletion request',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Deletes the request. Returns true when the server accepted it.
  Future<bool> withdraw() async {
    try {
      await _doc.delete().timeout(timeout);
      return true;
    } catch (e, st) {
      LoggerService.warn(
        'Could not withdraw deletion request',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
