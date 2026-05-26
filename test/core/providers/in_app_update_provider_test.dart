import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';

class MockInAppUpdateService extends Mock implements InAppUpdateService {}

class MockAppUpdateInfo extends Mock implements AppUpdateInfo {}

void main() {
  group('InAppUpdateState', () {
    group('default values', () {
      test('all fields are null or false by default', () {
        const state = InAppUpdateState();
        expect(state.updateInfo, isNull);
        expect(state.isChecking, isFalse);
        expect(state.isDownloading, isFalse);
        expect(state.error, isNull);
      });

      test('hasUpdate is false when updateInfo is null', () {
        const state = InAppUpdateState();
        expect(state.hasUpdate, isFalse);
      });

      test('immediateUpdateAllowed defaults to false when updateInfo is null', () {
        const state = InAppUpdateState();
        expect(state.immediateUpdateAllowed, isFalse);
      });

      test('flexibleUpdateAllowed defaults to false when updateInfo is null', () {
        const state = InAppUpdateState();
        expect(state.flexibleUpdateAllowed, isFalse);
      });

      test('isHighPriority defaults to false when updateInfo is null', () {
        const state = InAppUpdateState();
        expect(state.isHighPriority, isFalse);
      });
    });

    group('hasUpdate', () {
      test('returns true when update is available', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.hasUpdate, isTrue);
      });

      test('returns false when update is not available', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateNotAvailable);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.hasUpdate, isFalse);
      });

      test('returns false when update availability is unknown', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.unknown);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.hasUpdate, isFalse);
      });
    });

    group('isHighPriority', () {
      test('returns true for priority == 4', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updatePriority).thenReturn(4);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.isHighPriority, isTrue);
      });

      test('returns true for priority == 5 (maximum)', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updatePriority).thenReturn(5);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.isHighPriority, isTrue);
      });

      test('returns false for priority == 3', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updatePriority).thenReturn(3);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.isHighPriority, isFalse);
      });

      test('returns false for priority == 0 (minimum)', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updatePriority).thenReturn(0);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.isHighPriority, isFalse);
      });

      test('returns false when updateInfo is null', () {
        const state = InAppUpdateState();
        expect(state.isHighPriority, isFalse);
      });
    });

    group('immediateUpdateAllowed and flexibleUpdateAllowed', () {
      test('immediateUpdateAllowed reflects updateInfo value', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(true);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.immediateUpdateAllowed, isTrue);
      });

      test('immediateUpdateAllowed is false when updateInfo returns false', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.immediateUpdateAllowed, isFalse);
      });

      test('flexibleUpdateAllowed reflects updateInfo value', () {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        final state = InAppUpdateState(updateInfo: mockInfo);
        expect(state.flexibleUpdateAllowed, isTrue);
      });
    });

    group('copyWith sentinel pattern', () {
      test('preserves all values when called with no arguments', () {
        final mockInfo = MockAppUpdateInfo();
        final original = InAppUpdateState(
          updateInfo: mockInfo,
          isChecking: true,
          isDownloading: true,
          error: 'some error',
        );
        final copy = original.copyWith();
        expect(copy.updateInfo, same(mockInfo));
        expect(copy.isChecking, isTrue);
        expect(copy.isDownloading, isTrue);
        expect(copy.error, 'some error');
      });

      test('can explicitly clear updateInfo to null using sentinel', () {
        final mockInfo = MockAppUpdateInfo();
        final original = InAppUpdateState(updateInfo: mockInfo);
        // Pass explicit null to clear
        final copy = original.copyWith(updateInfo: null);
        expect(copy.updateInfo, isNull);
      });

      test('can explicitly clear error to null using sentinel', () {
        const original = InAppUpdateState(error: 'some error');
        final copy = original.copyWith(error: null);
        expect(copy.error, isNull);
      });

      test('updates only specified fields', () {
        final original = InAppUpdateState(
          isChecking: false,
          isDownloading: false,
          error: 'old error',
        );
        final copy = original.copyWith(isChecking: true);
        expect(copy.isChecking, isTrue);
        expect(copy.isDownloading, isFalse); // unchanged
        expect(copy.error, 'old error'); // unchanged
      });

      test('can update error while preserving other fields', () {
        final mockInfo = MockAppUpdateInfo();
        final original = InAppUpdateState(
          updateInfo: mockInfo,
          isChecking: false,
          isDownloading: false,
        );
        final copy = original.copyWith(error: 'new error');
        expect(copy.updateInfo, same(mockInfo));
        expect(copy.error, 'new error');
        expect(copy.isChecking, isFalse);
      });
    });
  });

  group('InAppUpdateNotifier', () {
    late MockInAppUpdateService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockInAppUpdateService();
      when(() => mockService.installUpdateListener)
          .thenAnswer((_) => const Stream.empty());
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

    group('checkForUpdate', () {
      test('sets isChecking to true during check, false after', () async {
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.unknown);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockUpdateInfo);

        final notifier = container.read(inAppUpdateProvider.notifier);
        final future = notifier.checkForUpdate();

        expect(container.read(inAppUpdateProvider).isChecking, isTrue);

        await future;

        expect(container.read(inAppUpdateProvider).isChecking, isFalse);
      });

      test('clears error when starting a new check', () async {
        // First, put the state into an error state
        when(() => mockService.checkForUpdate())
            .thenThrow(Exception('Network error'));
        await container.read(inAppUpdateProvider.notifier).checkForUpdate();
        expect(container.read(inAppUpdateProvider).error, isNotNull);

        // Reset mock to succeed
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateNotAvailable);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.unknown);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockUpdateInfo);

        await container.read(inAppUpdateProvider.notifier).checkForUpdate();

        expect(container.read(inAppUpdateProvider).error, isNull);
      });

      test('skips when already checking (no duplicate calls)', () async {
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateNotAvailable);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.unknown);

        // Simulate a slow check
        when(() => mockService.checkForUpdate()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return mockUpdateInfo;
        });

        final notifier = container.read(inAppUpdateProvider.notifier);

        // Start two checks simultaneously
        final future1 = notifier.checkForUpdate();
        final future2 = notifier.checkForUpdate(); // should be skipped

        await Future.wait([future1, future2]);

        // Service should only be called once
        verify(() => mockService.checkForUpdate()).called(1);
      });

      test('updates state when update available', () async {
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockUpdateInfo.immediateUpdateAllowed).thenReturn(true);
        when(() => mockUpdateInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockUpdateInfo.updatePriority).thenReturn(5);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.unknown);
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

      test('handles no update available', () async {
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateNotAvailable);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.unknown);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockUpdateInfo);

        await container.read(inAppUpdateProvider.notifier).checkForUpdate();

        final state = container.read(inAppUpdateProvider);

        expect(state.updateInfo, isNotNull);
        expect(state.hasUpdate, isFalse);
        expect(state.isChecking, isFalse);
      });

      test('sets isUpdateDownloaded to true when update is already downloaded', () async {
        final mockUpdateInfo = MockAppUpdateInfo();
        when(() => mockUpdateInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockUpdateInfo.installStatus)
            .thenReturn(InstallStatus.downloaded);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockUpdateInfo);

        await container.read(inAppUpdateProvider.notifier).checkForUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.isUpdateDownloaded, isTrue);
        expect(state.error, isNull);
      });

      test('handles service returning null', () async {
        when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

        await container.read(inAppUpdateProvider.notifier).checkForUpdate();

        final state = container.read(inAppUpdateProvider);

        expect(state.updateInfo, isNull);
        expect(state.hasUpdate, isFalse);
        expect(state.isChecking, isFalse);
        expect(state.error, isNull);
      });

      test('sets error message on exception', () async {
        when(() => mockService.checkForUpdate())
            .thenThrow(Exception('Network error'));

        await container.read(inAppUpdateProvider.notifier).checkForUpdate();

        final state = container.read(inAppUpdateProvider);

        expect(state.error, isNotNull);
        expect(state.error, 'Failed to check for updates. Please try again later.');
        expect(state.isChecking, isFalse);
      });
    });

    group('startImmediateUpdate', () {
      test('does not set error on success result', () async {
        when(() => mockService.startImmediateUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await container.read(inAppUpdateProvider.notifier).startImmediateUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, isNull);
      });

      test('sets error when result is inAppUpdateFailed', () async {
        when(() => mockService.startImmediateUpdate())
            .thenAnswer((_) async => AppUpdateResult.inAppUpdateFailed);

        await container.read(inAppUpdateProvider.notifier).startImmediateUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, 'Update installation failed. Please try again.');
      });

      test('sets error when result is userDeniedUpdate for immediate update', () async {
        when(() => mockService.startImmediateUpdate())
            .thenAnswer((_) async => AppUpdateResult.userDeniedUpdate);

        await container.read(inAppUpdateProvider.notifier).startImmediateUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, 'Update installation failed. Please try again.');
      });

      test('sets error when result is userDeniedUpdate', () async {
        when(() => mockService.startImmediateUpdate())
            .thenAnswer((_) async => AppUpdateResult.userDeniedUpdate);

        await container.read(inAppUpdateProvider.notifier).startImmediateUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, 'Update installation failed. Please try again.');
      });

      test('sets error message on exception', () async {
        when(() => mockService.startImmediateUpdate())
            .thenThrow(Exception('Platform error'));

        await container.read(inAppUpdateProvider.notifier).startImmediateUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, 'Failed to start update. Please try again later.');
      });
    });

    group('startFlexibleUpdate', () {
      test('skips when already downloading (no duplicate calls)', () async {
        when(() => mockService.startFlexibleUpdate()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return AppUpdateResult.success;
        });

        final notifier = container.read(inAppUpdateProvider.notifier);
        final future1 = notifier.startFlexibleUpdate();
        final future2 = notifier.startFlexibleUpdate(); // should be skipped

        await Future.wait([future1, future2]);

        verify(() => mockService.startFlexibleUpdate()).called(1);
      });

      test('sets isDownloading to true during download, remains true after start completes', () async {
        when(() => mockService.startFlexibleUpdate()).thenAnswer((_) async {
          return AppUpdateResult.success;
        });

        final notifier = container.read(inAppUpdateProvider.notifier);
        final future = notifier.startFlexibleUpdate();

        expect(container.read(inAppUpdateProvider).isDownloading, isTrue);

        await future;

        expect(container.read(inAppUpdateProvider).isDownloading, isTrue);
      });

      test('transitions state reactively based on installUpdateListener stream events', () async {
        final controller = StreamController<InstallStatus>();
        when(() => mockService.installUpdateListener).thenAnswer((_) => controller.stream);

        // Re-create the container to re-trigger build() with the mocked stream
        final testContainer = ProviderContainer(
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        addTearDown(testContainer.dispose);

        // Initial state should be false/false
        expect(testContainer.read(inAppUpdateProvider).isDownloading, isFalse);
        expect(testContainer.read(inAppUpdateProvider).isUpdateDownloaded, isFalse);

        // Emit downloading status
        controller.add(InstallStatus.downloading);
        await Future.delayed(Duration.zero); // yield to stream listener
        expect(testContainer.read(inAppUpdateProvider).isDownloading, isTrue);
        expect(testContainer.read(inAppUpdateProvider).isUpdateDownloaded, isFalse);

        // Emit downloaded status
        controller.add(InstallStatus.downloaded);
        await Future.delayed(Duration.zero); // yield to stream listener
        expect(testContainer.read(inAppUpdateProvider).isDownloading, isFalse);
        expect(testContainer.read(inAppUpdateProvider).isUpdateDownloaded, isTrue);

        await controller.close();
      });

      test('calls startFlexibleUpdate on the service', () async {
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

        verify(() => mockService.startFlexibleUpdate()).called(1);
      });

      test('clears isDownloading and sets error on failed result', () async {
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.inAppUpdateFailed);

        await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.isDownloading, isFalse);
        expect(state.error, 'Failed to download update. Please try again.');
      });

      test('sets error when result is userDeniedUpdate for flexible update', () async {
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.userDeniedUpdate);

        await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.isDownloading, isFalse);
        expect(state.error, 'Failed to download update. Please try again.');
      });

      test('clears isDownloading and sets error on exception', () async {
        when(() => mockService.startFlexibleUpdate())
            .thenThrow(Exception('Download failed'));

        await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.isDownloading, isFalse);
        expect(state.error, 'Failed to start update download. Please try again later.');
      });

      test('clears error before starting download', () async {
        // Put state into error
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.inAppUpdateFailed);
        await container.read(inAppUpdateProvider.notifier).startFlexibleUpdate();
        expect(container.read(inAppUpdateProvider).error, isNotNull);

        // Next call should clear error at start
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);
        final notifier = container.read(inAppUpdateProvider.notifier);
        final future = notifier.startFlexibleUpdate();

        // Error should be cleared immediately on start (isDownloading set)
        final midState = container.read(inAppUpdateProvider);
        expect(midState.isDownloading, isTrue);
        expect(midState.error, isNull);

        await future;
      });
    });

    group('completeFlexibleUpdate', () {
      test('calls completeFlexibleUpdate on the service', () async {
        when(() => mockService.completeFlexibleUpdate()).thenAnswer((_) async {});

        await container.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();

        verify(() => mockService.completeFlexibleUpdate()).called(1);
      });

      test('sets error message on exception', () async {
        when(() => mockService.completeFlexibleUpdate())
            .thenThrow(Exception('Restart failed'));

        await container.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, 'Failed to complete update. Please restart the app manually.');
      });

      test('does not update state on success', () async {
        when(() => mockService.completeFlexibleUpdate()).thenAnswer((_) async {});

        await container.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();

        final state = container.read(inAppUpdateProvider);
        expect(state.error, isNull);
      });
    });
  });
}
