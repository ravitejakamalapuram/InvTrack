/// Notifier for FIRE settings mutations (CRUD operations).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/analytics_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_settings_validator.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:uuid/uuid.dart';

/// Notifier for FIRE settings operations
class FireSettingsNotifier extends Notifier<AsyncValue<void>> {
  final Uuid _uuid = const Uuid();
  final FireSettingsValidator _validator = FireSettingsValidator();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Save or update FIRE settings.
  /// Validates settings before saving and throws [FireSettingsValidationException]
  /// if validation fails.
  Future<void> saveSettings(FireSettingsEntity settings) async {
    state = const AsyncValue.loading();
    try {
      // Validate settings before saving
      _validator.validateOrThrow(settings);

      final repository = ref.read(fireSettingsRepositoryProvider);
      await repository.saveSettings(settings);

      // Log analytics
      final analytics = ref.read(analyticsServiceProvider);
      analytics.logEvent(
        name: 'fire_settings_saved',
        parameters: {
          'fire_type': settings.fireType.name,
          'target_fire_age': settings.targetFireAge,
          'is_setup_complete': settings.isSetupComplete ? 1 : 0,
        },
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Create initial FIRE settings for a new user
  Future<FireSettingsEntity> createInitialSettings({
    required int currentAge,
  }) async {
    final settings = FireSettingsEntity.defaults(
      id: _uuid.v4(),
      currentAge: currentAge,
    );

    await saveSettings(settings);
    return settings;
  }

  /// Complete FIRE setup
  Future<void> completeSetup(FireSettingsEntity settings) async {
    final updatedSettings = settings.copyWith(
      isSetupComplete: true,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);

    // Log analytics
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logEvent(
      name: 'fire_setup_completed',
      parameters: {
        'fire_type': settings.fireType.name,
        'monthly_expenses_range': getAmountRange(settings.monthlyExpenses),
        'target_fire_age': settings.targetFireAge,
      },
    );
  }

  /// Update monthly expenses
  Future<void> updateMonthlyExpenses(double expenses) async {
    final currentSettings = ref.read(fireSettingsProvider).value;
    if (currentSettings == null) return;

    final updatedSettings = currentSettings.copyWith(
      monthlyExpenses: expenses,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  /// Update FIRE type
  Future<void> updateFireType(FireType fireType) async {
    final currentSettings = ref.read(fireSettingsProvider).value;
    if (currentSettings == null) return;

    final updatedSettings = currentSettings.copyWith(
      fireType: fireType,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  /// Update target FIRE age
  Future<void> updateTargetFireAge(int age) async {
    final currentSettings = ref.read(fireSettingsProvider).value;
    if (currentSettings == null) return;

    final updatedSettings = currentSettings.copyWith(
      targetFireAge: age,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  /// Update safe withdrawal rate
  Future<void> updateSafeWithdrawalRate(double rate) async {
    final currentSettings = ref.read(fireSettingsProvider).value;
    if (currentSettings == null) return;

    final updatedSettings = currentSettings.copyWith(
      safeWithdrawalRate: rate,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  /// Reset FIRE settings (delete and start over)
  Future<void> resetSettings() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(fireSettingsRepositoryProvider);
      await repository.deleteSettings();

      // Log analytics
      final analytics = ref.read(analyticsServiceProvider);
      analytics.logEvent(name: 'fire_settings_reset');

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider for FIRE settings notifier
final fireSettingsNotifierProvider =
    NotifierProvider<FireSettingsNotifier, AsyncValue<void>>(
      FireSettingsNotifier.new,
    );
