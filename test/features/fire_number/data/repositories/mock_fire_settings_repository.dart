import 'dart:async';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';

/// Fake implementation of FireSettingsRepository for testing.
/// Maintains in-memory state for unit and integration tests.
class FakeFireSettingsRepository implements FireSettingsRepository {
  FireSettingsEntity? _settings;
  final _controller = StreamController<FireSettingsEntity?>.broadcast();

  /// Access settings for test assertions
  FireSettingsEntity? get settings => _settings;

  /// Reset repository state
  void reset() {
    _settings = null;
    _controller.add(null);
  }

  /// Seed with test data
  void seed(FireSettingsEntity settings) {
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Stream<FireSettingsEntity?> watchSettings() {
    // Emit current value immediately, then stream updates
    return _controller.stream.asBroadcastStream()
      ..first.then((_) {}); // Subscribe to keep stream alive
  }

  @override
  Future<FireSettingsEntity?> getSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Future<void> deleteSettings() async {
    _settings = null;
    _controller.add(null);
  }

  @override
  Future<bool> hasCompletedSetup() async {
    return _settings?.isSetupComplete ?? false;
  }

  /// Dispose resources
  void dispose() {
    _controller.close();
  }
}

