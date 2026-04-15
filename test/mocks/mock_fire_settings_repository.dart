/// Mock implementation of FireSettingsRepository for testing.
library;

import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';

/// Mock repository for testing FireSettingsNotifier.
///
/// Stores settings in memory and provides synchronous stream for testing.
class MockFireSettingsRepository implements FireSettingsRepository {
  FireSettingsEntity? _settings;

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    _settings = settings;
  }

  @override
  Future<FireSettingsEntity?> getSettings() async {
    return _settings;
  }

  @override
  Stream<FireSettingsEntity?> watchSettings() {
    return Stream.value(_settings);
  }

  @override
  Future<bool> hasCompletedSetup() async {
    return _settings?.isSetupComplete ?? false;
  }

  @override
  Future<void> deleteSettings() async {
    _settings = null;
  }

  /// Reset repository state for next test
  void reset() {
    _settings = null;
  }

  /// Get current settings (for test assertions)
  FireSettingsEntity? get settings => _settings;
}
