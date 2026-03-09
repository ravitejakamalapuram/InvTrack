import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';

/// Repository interface for user profile operations
abstract class UserProfileRepository {
  /// Watch user profile changes in real-time
  Stream<UserProfileEntity?> watchProfile();

  /// Get user profile (one-time fetch)
  Future<UserProfileEntity?> getProfile();

  /// Save or update user profile
  Future<void> saveProfile(UserProfileEntity profile);

  /// Delete user profile
  Future<void> deleteProfile();

  /// Check if profile exists
  Future<bool> profileExists();
}
