import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';

import 'fake_deletion_request_service.dart';

/// Overrides for providers that would build a Firestore client.
///
/// The integration harness never calls `Firebase.initializeApp()`, so any
/// provider that reaches `FirebaseFirestore.instance` throws `[core/no-app]`.
/// Every harness adds these next to its repository fakes.
List<Override> noFirebaseOverrides() => [
  deletionRequestServiceProvider.overrideWithValue(
    FakeDeletionRequestService(),
  ),
  currencyConversionServiceProvider.overrideWithValue(null),
];
