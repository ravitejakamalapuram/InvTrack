import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';

/// Deletion-request queue with no Firestore behind it, for integration tests.
///
/// The harness has no Firebase app, so the real service cannot be built. This
/// one reports that nothing is queued, which is what a user who never asked
/// for deletion sees.
class FakeDeletionRequestService implements DeletionRequestService {
  @override
  Future<bool> hasRequest() async => false;

  @override
  Future<DeletionRequestStatus> requestStatus() async =>
      DeletionRequestStatus.none;

  @override
  Stream<DeletionRequestStatus> watchStatus() =>
      Stream.value(DeletionRequestStatus.none);

  @override
  Future<bool> pendingWritesSent() async => true;

  @override
  Future<bool> requestDeletion() async => true;

  @override
  Future<bool> withdraw() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
