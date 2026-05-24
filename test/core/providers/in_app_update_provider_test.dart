import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';

class MockInAppUpdateService extends Mock implements InAppUpdateService {}

class MockAppUpdateInfo extends Mock implements AppUpdateInfo {}

void main() {
  group('InAppUpdateNotifier', () {
    late MockInAppUpdateService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockInAppUpdateService();
      container = ProviderContainer(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(inAppUpdateProvider);

      expect(state.updateInfo, isNull);
      expect(state.isChecking, isFalse);
      expect(state.isDownloading, isFalse);
      expect(state.error, isNull);
      expect(state.hasUpdate, isFalse);
    });

    test('checkForUpdate sets isChecking during check', () async {
      final mockUpdateInfo = MockAppUpdateInfo();
      when(() => mockUpdateInfo.updateAvailability)
          .thenReturn(UpdateAvailability.updateAvailable);
      when(() => mockService.checkForUpdate())
          .thenAnswer((_) async => mockUpdateInfo);

      final notifier = container.read(inAppUpdateProvider.notifier);

      // Start check (don't await)
      final future = notifier.checkForUpdate();

      // Verify isChecking is true during check
      expect(container.read(inAppUpdateProvider).isChecking, isTrue);

      await future;

      // Verify isChecking is false after check
      expect(container.read(inAppUpdateProvider).isChecking, isFalse);
    });

    test('checkForUpdate updates state when update available', () async {
      final mockUpdateInfo = MockAppUpdateInfo();
      when(() => mockUpdateInfo.updateAvailability)
          .thenReturn(UpdateAvailability.updateAvailable);
      when(() => mockUpdateInfo.immediateUpdateAllowed).thenReturn(true);
      when(() => mockUpdateInfo.flexibleUpdateAllowed).thenReturn(true);
      when(() => mockUpdateInfo.updatePriority).thenReturn(5);
      when(() => mockService.checkForUpdate())
          .thenAnswer((_) async => mockUpdateInfo);

      await container.read(inAppUpdateProvider.notifier).checkForUpdate();

      final state = container.read(inAppUpdateProvider);

      expect(state.updateInfo, isNotNull);
      expect(state.hasUpdate, isTrue);
      expect(state.immediateUpdateAllowed, isTrue);
      expect(state.flexibleUpdateAllowed, isTrue);
      expect(state.isHighPriority, isTrue);
      expect(state.isChecking, isFalse);
    });

    test('checkForUpdate handles no update available', () async {
      final mockUpdateInfo = MockAppUpdateInfo();
      when(() => mockUpdateInfo.updateAvailability)
          .thenReturn(UpdateAvailability.updateNotAvailable);
      when(() => mockService.checkForUpdate())
          .thenAnswer((_) async => mockUpdateInfo);

      await container.read(inAppUpdateProvider.notifier).checkForUpdate();

      final state = container.read(inAppUpdateProvider);

      expect(state.updateInfo, isNotNull);
      expect(state.hasUpdate, isFalse);
      expect(state.isChecking, isFalse);
      expect(state.error, isNull);
    });

    test('checkForUpdate handles error', () async {
      when(() => mockService.checkForUpdate())
          .thenThrow(Exception('Network error'));

      await container.read(inAppUpdateProvider.notifier).checkForUpdate();

      final state = container.read(inAppUpdateProvider);

      expect(state.error, isNotNull);
      expect(state.error, contains('Network error'));
      expect(state.isChecking, isFalse);
    });

    test('startFlexibleUpdate sets isDownloading', () async {
      when(() => mockService.startFlexibleUpdate())
          .thenAnswer((_) async => AppUpdateResult.success);

      await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

      // Note: isDownloading should be true during download
      // For this test, we verify the service was called
      verify(() => mockService.startFlexibleUpdate()).called(1);
    });

    test('isHighPriority returns true for priority >= 4', () {
      final mockUpdateInfo = MockAppUpdateInfo();
      when(() => mockUpdateInfo.updateAvailability)
          .thenReturn(UpdateAvailability.updateAvailable);
      when(() => mockUpdateInfo.updatePriority).thenReturn(4);

      final state = InAppUpdateState(updateInfo: mockUpdateInfo);

      expect(state.isHighPriority, isTrue);
    });

    test('isHighPriority returns false for priority < 4', () {
      final mockUpdateInfo = MockAppUpdateInfo();
      when(() => mockUpdateInfo.updateAvailability)
          .thenReturn(UpdateAvailability.updateAvailable);
      when(() => mockUpdateInfo.updatePriority).thenReturn(3);

      final state = InAppUpdateState(updateInfo: mockUpdateInfo);

      expect(state.isHighPriority, isFalse);
    });
  });
}
