/// Regression tests for FireSettingsNotifier analytics privacy compliance.
///
/// Tests verify that analytics events mask sensitive financial data using
/// privacy-safe range buckets instead of exact amounts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_fire_settings_repository.dart';

void main() {
  late MockFireSettingsRepository mockRepository;
  late FakeAnalyticsService fakeAnalytics;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockFireSettingsRepository();
    fakeAnalytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        fireSettingsRepositoryProvider.overrideWithValue(mockRepository),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeAnalytics.reset();
  });

  group('FireSettingsNotifier - Analytics Privacy', () {
    test(
        'completeSetup logs monthly_expenses_range (not exact monthly_expenses)',
        () async {
      // Arrange: Create settings with known monthly expenses
      final settings = FireSettingsEntity.defaults(
        id: 'test-id',
        currentAge: 30,
      ).copyWith(
        monthlyExpenses: 75000, // Known amount: should map to '50k_1L' range
        fireType: FireType.lean,
        targetFireAge: 55,
      );

      // Act: Complete FIRE setup (triggers analytics)
      final notifier = container.read(fireSettingsNotifierProvider.notifier);
      await notifier.completeSetup(settings);

      // Assert: Verify analytics event was logged
      expect(fakeAnalytics.loggedEvents, hasLength(2)); // saveSettings + completeSetup

      // Find the fire_setup_completed event
      final setupCompletedEvent = fakeAnalytics.loggedEvents.firstWhere(
        (event) => event.name == 'fire_setup_completed',
      );

      // Assert: Event parameters contain masked amount (not exact)
      final params = setupCompletedEvent.parameters!;

      // ✅ MUST contain privacy-safe range
      expect(params, containsPair('monthly_expenses_range', '50k_1L'));

      // ✅ MUST NOT contain exact amount (privacy violation)
      expect(params, isNot(contains('monthly_expenses')));

      // ✅ Verify other parameters are correct
      expect(params, containsPair('fire_type', 'lean'));
      expect(params, containsPair('target_fire_age', 55));
    });

    test('completeSetup uses correct range buckets for different amounts',
        () async {
      // Test multiple amounts to verify range bucketing
      final testCases = [
        (amount: 500.0, expectedRange: 'under_1k'),
        (amount: 5000.0, expectedRange: '1k_10k'),
        (amount: 25000.0, expectedRange: '10k_50k'),
        (amount: 75000.0, expectedRange: '50k_1L'),
        (amount: 250000.0, expectedRange: '1L_5L'),
        (amount: 750000.0, expectedRange: '5L_10L'),
        (amount: 2500000.0, expectedRange: 'over_10L'),
      ];

      for (final testCase in testCases) {
        // Reset analytics between test cases
        fakeAnalytics.reset();

        final settings = FireSettingsEntity.defaults(
          id: 'test-id-${testCase.amount}',
          currentAge: 30,
        ).copyWith(
          monthlyExpenses: testCase.amount,
        );

        final notifier = container.read(fireSettingsNotifierProvider.notifier);
        await notifier.completeSetup(settings);

        final setupEvent = fakeAnalytics.loggedEvents.firstWhere(
          (event) => event.name == 'fire_setup_completed',
        );
        final params = setupEvent.parameters!;

        expect(
          params['monthly_expenses_range'],
          testCase.expectedRange,
          reason:
              'Amount ${testCase.amount} should map to ${testCase.expectedRange}',
        );
      }
    });

    test('saveSettings does not log exact monetary amounts', () async {
      // Arrange
      final settings = FireSettingsEntity.defaults(
        id: 'test-id',
        currentAge: 30,
      ).copyWith(
        monthlyExpenses: 50000,
      );

      // Act
      final notifier = container.read(fireSettingsNotifierProvider.notifier);
      await notifier.saveSettings(settings);

      // Assert: Verify no exact amounts in any analytics events
      for (final event in fakeAnalytics.loggedEvents) {
        final params = event.parameters ?? {};

        // Should never contain exact monthly_expenses
        expect(
          params,
          isNot(contains('monthly_expenses')),
          reason: 'Event ${event.name} must not log exact amounts',
        );
      }
    });
  });
}
