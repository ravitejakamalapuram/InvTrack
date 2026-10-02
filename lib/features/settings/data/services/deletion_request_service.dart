import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Reads, files and withdraws the account-deletion request document
/// `deletionRequests/{uid}`.
///
/// The same queue is used by the web request page. A daily server job deletes
/// the account once the request is older than the 24 hour withdrawal window,
/// which also finishes deletions the app could not complete itself (offline,
/// failed re-auth). The app only withdraws from the sign-in notice; a
/// cancelled re-auth happens before anything is filed.
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
    } catch (e) {
      LoggerService.warn('Could not read deletion request: $e');
      return false;
    }
  }

  /// Files a request with source `app`. Returns true only when THIS call
  /// created it, so the caller knows whether it may withdraw it later (an
  /// existing request, e.g. from the web, must be left alone). Never throws:
  /// a failure is logged and deletion proceeds on the client path.
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
    } catch (e) {
      LoggerService.warn('Could not file deletion request: $e');
      return false;
    }
  }

  /// Deletes the request. Returns true when the server accepted it.
  Future<bool> withdraw() async {
    try {
      await _doc.delete().timeout(timeout);
      return true;
    } catch (e) {
      LoggerService.warn('Could not withdraw deletion request: $e');
      return false;
    }
  }
}
