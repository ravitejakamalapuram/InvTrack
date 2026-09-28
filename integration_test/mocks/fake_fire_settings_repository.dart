import 'dart:async';

import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';

/// In-memory FIRE settings repository for tests and screenshot capture.
/// Avoids the real Firestore-backed repository so tests don't need network.
class FakeFireSettingsRepository implements FireSettingsRepository {
  FireSettingsEntity? _settings;
  final _controller = StreamController<FireSettingsEntity?>.broadcast();

  FakeFireSettingsRepository({FireSettingsEntity? initialSettings})
    : _settings = initialSettings;

  @override
  Stream<FireSettingsEntity?> watchSettings() async* {
    yield _settings;
    yield* _controller.stream;
  }

  @override
  Future<FireSettingsEntity?> getSettings() async => _settings;

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    _settings = settings;
    _controller.add(_settings);
  }

  @override
  Future<void> deleteSettings() async {
    _settings = null;
    _controller.add(_settings);
  }

  @override
  Future<bool> hasCompletedSetup() async => _settings?.isSetupComplete ?? false;
}
