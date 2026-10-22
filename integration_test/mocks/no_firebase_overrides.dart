import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';

import 'fake_deletion_request_service.dart';

/// Stands in for Firestore so providers can be built without a Firebase app.
/// Any call on it throws, so a test that reaches Firestore fails loudly.
class UnavailableFirestore extends Fake implements FirebaseFirestore {}

/// Overrides for providers that would build a Firestore client.
///
/// The integration harness never calls `Firebase.initializeApp()`, so any
/// provider that reaches `FirebaseFirestore.instance` throws `[core/no-app]`
/// the first time a screen reads it. Every harness adds these next to its
/// repository fakes.
List<Override> noFirebaseOverrides() => [
  firestoreProvider.overrideWithValue(UnavailableFirestore()),
  deletionRequestServiceProvider.overrideWithValue(
    FakeDeletionRequestService(),
  ),
  currencyConversionServiceProvider.overrideWithValue(null),
];
