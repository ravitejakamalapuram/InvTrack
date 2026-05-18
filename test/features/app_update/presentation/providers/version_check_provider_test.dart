/// Unit tests for VersionCheckNotifier.
///
/// Tests beta detection logic, state management, and version comparison.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/app_update/data/services/version_check_service.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';
import 'package:inv_tracker/features/app_update/presentation/providers/version_check_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Mock classes
class MockVersionCheckService extends Mock implements VersionCheckService {}

void main() {
  // Setup mock package info
  PackageInfo.setMockInitialValues(
    appName: 'InvTrack',
    packageName: 'com.invtracker.inv_tracker',
    version: '1.0.0',
    buildNumber: '100',
    buildSignature: '',
  );

  late MockVersionCheckService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockVersionCheckService();
  });

  tearDown(() {
    container.dispose();
  });

  group('VersionCheckNotifier', () {
    group('Beta Detection', () {
      test('detects production build (no .beta suffix)', () async {
        // Arrange
        PackageInfo.setMockInitialValues(
          appName: 'InvTrack',
          packageName: 'com.invtracker.inv_tracker', // No .beta suffix
          version: '1.0.0',
          buildNumber: '100',
          buildSignature: '',
        );

        when(() => mockService.fetchLatestVersion(isBetaUser: false))
            .thenAnswer((_) async => const AppVersionEntity(
                  latestVersion: '1.1.0',
                  latestBuildNumber: 110,
                  minimumVersion: '1.0.0',
                  minimumBuildNumber: 100,
                  forceUpdate: false,
                  updateMessage: 'Update available',
                  whatsNew: '- Bug fixes',
                  downloadUrl: 'https://play.google.com/store/apps',
                ));

        container = ProviderContainer(
          overrides: [
            versionCheckServiceProvider.overrideWithValue(mockService),
          ],
        );

        // Act
        final notifier = container.read(versionCheckProvider.notifier);
        await notifier.checkForUpdates();

        // Assert
        verify(() => mockService.fetchLatestVersion(isBetaUser: false)).called(1);
        verifyNever(() => mockService.fetchLatestVersion(isBetaUser: true));
      });

      test('detects beta build (.beta suffix)', () async {
        // Arrange
        PackageInfo.setMockInitialValues(
          appName: 'InvTrack',
          packageName: 'com.invtracker.inv_tracker.beta', // Has .beta suffix
          version: '1.0.0-beta.1',
          buildNumber: '100',
          buildSignature: '',
        );

        when(() => mockService.fetchLatestVersion(isBetaUser: true))
            .thenAnswer((_) async => const AppVersionEntity(
                  latestVersion: '1.1.0-beta.1',
                  latestBuildNumber: 110,
                  minimumVersion: '1.0.0',
                  minimumBuildNumber: 100,
                  forceUpdate: false,
                  updateMessage: 'Beta update available',
                  whatsNew: '- Beta features',
                  downloadUrl: 'https://play.google.com/store/apps',
                ));

        container = ProviderContainer(
          overrides: [
            versionCheckServiceProvider.overrideWithValue(mockService),
          ],
        );

        // Act
        final notifier = container.read(versionCheckProvider.notifier);
        await notifier.checkForUpdates();

        // Assert
        verify(() => mockService.fetchLatestVersion(isBetaUser: true)).called(1);
        verifyNever(() => mockService.fetchLatestVersion(isBetaUser: false));
      });
    });

    group('State Management', () {
      test('updates state with latest version info', () async {
        // Arrange
        PackageInfo.setMockInitialValues(
          appName: 'InvTrack',
          packageName: 'com.invtracker.inv_tracker',
          version: '1.0.0',
          buildNumber: '100',
          buildSignature: '',
        );

        const latestVersion = AppVersionEntity(
          latestVersion: '1.1.0',
          latestBuildNumber: 110,
          minimumVersion: '1.0.0',
          minimumBuildNumber: 100,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        when(() => mockService.fetchLatestVersion(isBetaUser: false))
            .thenAnswer((_) async => latestVersion);

        container = ProviderContainer(
          overrides: [
            versionCheckServiceProvider.overrideWithValue(mockService),
          ],
        );

        // Act
        final notifier = container.read(versionCheckProvider.notifier);
        await notifier.checkForUpdates();

        final state = container.read(versionCheckProvider);

        // Assert
        expect(state.latestVersion, latestVersion);
        expect(state.hasChecked, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.currentVersion, '1.0.0');
        expect(state.currentBuildNumber, 100);
      });

      test('sets hasUpdate to true when update available', () async {
        // Arrange
        PackageInfo.setMockInitialValues(
          appName: 'InvTrack',
          packageName: 'com.invtracker.inv_tracker',
          version: '1.0.0',
          buildNumber: '100', // Current build
          buildSignature: '',
        );

        when(() => mockService.fetchLatestVersion(isBetaUser: false))
            .thenAnswer((_) async => const AppVersionEntity(
                  latestVersion: '1.1.0',
                  latestBuildNumber: 110, // Newer build
                  minimumVersion: '1.0.0',
                  minimumBuildNumber: 100,
                  forceUpdate: false,
                  updateMessage: 'Update available',
                  whatsNew: '- Bug fixes',
                  downloadUrl: 'https://play.google.com/store/apps',
                ));

        container = ProviderContainer(
          overrides: [
            versionCheckServiceProvider.overrideWithValue(mockService),
          ],
        );

        // Act & Assert - must watch state before calling checkForUpdates
        final notifier = container.read(versionCheckProvider.notifier);
        await notifier.checkForUpdates();
        
        final state = container.read(versionCheckProvider);
        expect(state.hasUpdate, isTrue);
      });
    });
  });
}
