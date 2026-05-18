/// Unit tests for AppVersionEntity.
///
/// Tests version comparison logic, force update detection, and beta detection.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';

void main() {
  group('AppVersionEntity', () {
    group('Initialization', () {
      test('creates entity with all required fields', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.latestVersion, '1.0.0');
        expect(entity.latestBuildNumber, 100);
        expect(entity.minimumVersion, '0.9.0');
        expect(entity.minimumBuildNumber, 90);
        expect(entity.forceUpdate, isFalse);
        expect(entity.updateMessage, 'Update available');
        expect(entity.whatsNew, '- Bug fixes');
        expect(entity.downloadUrl, 'https://play.google.com/store/apps');
      });
    });

    group('isOutdated', () {
      test('returns true when current build is older than latest', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.isOutdated(99), isTrue);
        expect(entity.isOutdated(50), isTrue);
        expect(entity.isOutdated(1), isTrue);
      });

      test('returns false when current build equals latest', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.isOutdated(100), isFalse);
      });

      test('returns false when current build is newer than latest', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.isOutdated(101), isFalse);
        expect(entity.isOutdated(200), isFalse);
      });
    });

    group('requiresForceUpdate', () {
      test('returns true when forceUpdate flag is set AND current build is below minimum', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: true, // Force update enabled
          updateMessage: 'Critical update required',
          whatsNew: '- Security fix',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        // Both conditions must be true: forceUpdate=true AND currentBuildNumber < minimumBuildNumber
        expect(entity.requiresForceUpdate(50), isTrue);  // 50 < 90
        expect(entity.requiresForceUpdate(89), isTrue);  // 89 < 90
        expect(entity.requiresForceUpdate(90), isFalse); // 90 not < 90
        expect(entity.requiresForceUpdate(95), isFalse); // 95 not < 90
      });

      test('returns false when current build is below minimum but forceUpdate is false', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false, // Force update disabled
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        // forceUpdate must be true for force update to apply
        expect(entity.requiresForceUpdate(89), isFalse);
        expect(entity.requiresForceUpdate(50), isFalse);
        expect(entity.requiresForceUpdate(1), isFalse);
      });

      test('returns false when current build meets minimum and forceUpdate is false', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.requiresForceUpdate(90), isFalse);
        expect(entity.requiresForceUpdate(95), isFalse);
        expect(entity.requiresForceUpdate(100), isFalse);
        expect(entity.requiresForceUpdate(101), isFalse);
      });

      test('edge case: current build equals minimum build', () {
        const entity = AppVersionEntity(
          latestVersion: '1.0.0',
          latestBuildNumber: 100,
          minimumVersion: '0.9.0',
          minimumBuildNumber: 90,
          forceUpdate: false,
          updateMessage: 'Update available',
          whatsNew: '- Bug fixes',
          downloadUrl: 'https://play.google.com/store/apps',
        );

        expect(entity.requiresForceUpdate(90), isFalse);
      });
    });
  });
}
