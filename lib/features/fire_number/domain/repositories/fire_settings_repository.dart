import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Repository interface for FIRE settings persistence
abstract class FireSettingsRepository {
  /// Watch the user's FIRE settings (real-time updates)
  Stream<FireSettingsEntity?> watchSettings();

  /// Get the user's FIRE settings
  Future<FireSettingsEntity?> getSettings();

  /// Create or update FIRE settings
  Future<void> saveSettings(FireSettingsEntity settings);

  /// Delete FIRE settings (reset)
  Future<void> deleteSettings();

  /// Check if user has completed FIRE setup
  Future<bool> hasCompletedSetup();
}
