import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/fire_number/data/models/fire_settings_model.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';

/// Firestore implementation of FIRE settings repository
class FirestoreFireSettingsRepository implements FireSettingsRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations (offline-first pattern)
  static const _writeTimeout = Duration(seconds: 5);

  FirestoreFireSettingsRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  /// FIRE settings document reference (single document per user)
  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('users').doc(_userId).collection('fireSettings').doc('settings');

  /// Execute write with timeout (offline-first pattern)
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write cached locally, will sync when online
    }
  }

  @override
  Stream<FireSettingsEntity?> watchSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return FireSettingsModel.fromFirestore(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<FireSettingsEntity?> getSettings() async {
    final snapshot = await _settingsRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return FireSettingsModel.fromFirestore(snapshot.data()!, snapshot.id);
  }

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    await _executeWrite(
      () => _settingsRef.set(
        FireSettingsModel.toFirestore(settings),
        SetOptions(merge: true),
      ),
    );
  }

  @override
  Future<void> deleteSettings() async {
    await _executeWrite(() => _settingsRef.delete());
  }

  @override
  Future<bool> hasCompletedSetup() async {
    final settings = await getSettings();
    return settings?.isSetupComplete ?? false;
  }
}

