import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/user_profile/data/models/user_profile_model.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/repositories/user_profile_repository.dart';

/// Firestore implementation of user profile repository
class FirestoreUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations (offline-first pattern)
  static const _writeTimeout = Duration(seconds: 5);

  FirestoreUserProfileRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  /// User profile document reference
  DocumentReference<Map<String, dynamic>> get _profileRef => _firestore
      .collection('users')
      .doc(_userId)
      .collection('profile')
      .doc('settings');

  /// Execute write with timeout (offline-first pattern)
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write cached locally, will sync when online
    }
  }

  @override
  Stream<UserProfileEntity?> watchProfile() {
    return _profileRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfileModel.fromFirestore(snapshot.data()!, _userId);
    });
  }

  @override
  Future<UserProfileEntity?> getProfile() async {
    final snapshot = await _profileRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return UserProfileModel.fromFirestore(snapshot.data()!, _userId);
  }

  @override
  Future<void> saveProfile(UserProfileEntity profile) async {
    await _executeWrite(
      () => _profileRef.set(
        UserProfileModel.toFirestore(profile),
        SetOptions(merge: true),
      ),
    );
  }

  @override
  Future<void> deleteProfile() async {
    await _executeWrite(() => _profileRef.delete());
  }

  @override
  Future<bool> profileExists() async {
    final snapshot = await _profileRef.get();
    return snapshot.exists;
  }
}
