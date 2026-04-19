// Tests verifying that the Crashlytics build configuration is correctly applied
// for both Android and iOS platforms.
//
// These tests validate the build configuration files directly to ensure that
// symbol upload settings are present and correct. This prevents regressions
// where the Crashlytics plugin or symbol upload configuration is accidentally
// removed, which would cause crash reports to lose symbolicated stack traces.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Resolves a path relative to the project root (two levels above test/).
String projectPath(String relativePath) {
  // When running via `flutter test`, the working directory is the project root.
  return relativePath;
}

void main() {
  group('Android Crashlytics build configuration', () {
    late String settingsContent;
    late String appBuildContent;

    setUpAll(() {
      settingsContent =
          File(projectPath('android/settings.gradle.kts')).readAsStringSync();
      appBuildContent =
          File(projectPath('android/app/build.gradle.kts')).readAsStringSync();
    });

    group('settings.gradle.kts – plugin declaration', () {
      test('declares Crashlytics Gradle plugin', () {
        expect(
          settingsContent,
          contains('com.google.firebase.crashlytics'),
          reason:
              'settings.gradle.kts must declare the Crashlytics Gradle plugin',
        );
      });

      test('declares Crashlytics plugin with version 3.0.2', () {
        expect(
          settingsContent,
          contains(
            'id("com.google.firebase.crashlytics") version "3.0.2" apply false',
          ),
          reason:
              'Crashlytics plugin must be declared at version 3.0.2 with apply false',
        );
      });

      test('uses apply false so the plugin is not applied to the root project',
          () {
        // The declaration in settings.gradle.kts must include `apply false`
        // so the plugin is applied only in app/build.gradle.kts.
        final crashlyticsLine = settingsContent
            .split('\n')
            .firstWhere(
              (line) => line.contains('com.google.firebase.crashlytics'),
              orElse: () => '',
            );
        expect(
          crashlyticsLine,
          contains('apply false'),
          reason:
              'Root-level plugin declaration must include "apply false" to avoid '
              'applying it to the settings project itself',
        );
      });

      test('plugin version is a non-empty string', () {
        final versionPattern = RegExp(
          r'id\("com\.google\.firebase\.crashlytics"\)\s+version\s+"([^"]+)"',
        );
        final match = versionPattern.firstMatch(settingsContent);
        expect(match, isNotNull,
            reason: 'Crashlytics plugin version declaration not found');
        expect(
          match!.group(1),
          isNotEmpty,
          reason: 'Crashlytics plugin version must not be empty',
        );
      });
    });

    group('app/build.gradle.kts – plugin application', () {
      test('applies the Crashlytics plugin in the plugins block', () {
        expect(
          appBuildContent,
          contains('id("com.google.firebase.crashlytics")'),
          reason:
              'app/build.gradle.kts must apply the Crashlytics plugin so that '
              'the symbol upload task is registered',
        );
      });

      test('Crashlytics plugin appears inside the plugins { } block', () {
        // The plugins block starts before the `android { }` block.
        final pluginsBlock = RegExp(
          r'plugins\s*\{([^}]+)\}',
          dotAll: true,
        ).firstMatch(appBuildContent);
        expect(pluginsBlock, isNotNull,
            reason: 'Could not locate plugins { } block');
        expect(
          pluginsBlock!.group(1),
          contains('com.google.firebase.crashlytics'),
          reason:
              'Crashlytics plugin id must be inside the plugins { } block, '
              'not elsewhere in the file',
        );
      });
    });

    group('app/build.gradle.kts – ProGuard mapping upload', () {
      test('enables mappingFileUploadEnabled in the release build type', () {
        expect(
          appBuildContent,
          contains('mappingFileUploadEnabled = true'),
          reason:
              'mappingFileUploadEnabled must be set to true so that ProGuard/R8 '
              'mapping files are uploaded to Firebase on every release build, '
              'enabling symbolicated crash reports',
        );
      });

      test('configures CrashlyticsExtension in the release build type', () {
        expect(
          appBuildContent,
          contains(
              'configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension>'),
          reason:
              'The CrashlyticsExtension must be configured via configure<> so '
              'that Gradle can locate and apply the extension at build time',
        );
      });

      test('mapping upload configuration is inside the release { } block', () {
        // Extract the release build-type block heuristically.
        final releaseBlockMatch = RegExp(
          r'release\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}',
          dotAll: true,
        ).firstMatch(appBuildContent);
        expect(releaseBlockMatch, isNotNull,
            reason: 'Could not locate release { } build type block');
        expect(
          releaseBlockMatch!.group(1),
          contains('mappingFileUploadEnabled = true'),
          reason:
              'mappingFileUploadEnabled = true must be inside the release build '
              'type block, not in debug or other build types',
        );
      });

      test('mappingFileUploadEnabled is not set to false', () {
        // Guard against a future accidental reversion.
        expect(
          appBuildContent,
          isNot(contains('mappingFileUploadEnabled = false')),
          reason:
              'mappingFileUploadEnabled must not be false; that would silently '
              'disable symbol uploads and make crash reports unreadable',
        );
      });
    });
  });

  group('iOS Crashlytics build configuration', () {
    late String podfileContent;

    setUpAll(() {
      podfileContent =
          File(projectPath('ios/Podfile')).readAsStringSync();
    });

    group('Podfile – dSYM generation', () {
      test('sets DEBUG_INFORMATION_FORMAT to dwarf-with-dsym', () {
        expect(
          podfileContent,
          contains("config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'"),
          reason:
              "DEBUG_INFORMATION_FORMAT must be set to 'dwarf-with-dsym' so that "
              'Xcode generates dSYM files for every pod target, which are then '
              'uploaded by the Firebase SDK for crash symbolication',
        );
      });

      test('DEBUG_INFORMATION_FORMAT is not set to plain dwarf', () {
        // 'dwarf' (without -with-dsym) does not produce dSYM bundles.
        final lines = podfileContent.split('\n');
        for (final line in lines) {
          if (line.contains('DEBUG_INFORMATION_FORMAT') &&
              !line.trimLeft().startsWith('#')) {
            expect(
              line,
              isNot(contains("= 'dwarf'")),
              reason:
                  "Setting DEBUG_INFORMATION_FORMAT to 'dwarf' would suppress "
                  'dSYM generation and break Crashlytics symbolication',
            );
          }
        }
      });

      test('dSYM setting is inside the post_install hook', () {
        final postInstallBlock = RegExp(
          r'post_install\s+do\s+\|installer\|(.*?)^end',
          dotAll: true,
          multiLine: true,
        ).firstMatch(podfileContent);
        expect(postInstallBlock, isNotNull,
            reason: 'post_install block not found in Podfile');
        expect(
          postInstallBlock!.group(1),
          contains('DEBUG_INFORMATION_FORMAT'),
          reason:
              'DEBUG_INFORMATION_FORMAT must be configured inside the '
              'post_install block so it applies after CocoaPods resolves pods',
        );
      });

      test('dSYM setting is inside the build_configurations loop', () {
        // The setting must be applied per build configuration (Debug/Release/Profile).
        final loopBlock = RegExp(
          r'build_configurations\.each\s+do\s+\|config\|(.*?)end',
          dotAll: true,
        ).firstMatch(podfileContent);
        expect(loopBlock, isNotNull,
            reason: 'build_configurations.each loop not found');
        expect(
          loopBlock!.group(1),
          contains('DEBUG_INFORMATION_FORMAT'),
          reason:
              'DEBUG_INFORMATION_FORMAT must be set inside the '
              'build_configurations.each loop so every configuration '
              '(Debug, Release, Profile) generates dSYM files',
        );
      });

      test('dSYM format value uses correct hyphenated form', () {
        // Firebase / Xcode require exactly 'dwarf-with-dsym'.
        final formatMatch = RegExp(
          r"DEBUG_INFORMATION_FORMAT'\]\s*=\s*'([^']+)'",
        ).firstMatch(podfileContent);
        expect(formatMatch, isNotNull,
            reason: 'DEBUG_INFORMATION_FORMAT assignment not found');
        expect(
          formatMatch!.group(1),
          equals('dwarf-with-dsym'),
          reason:
              "The value must be exactly 'dwarf-with-dsym' (hyphenated), "
              "not 'DWARF with dSYM' or any other variant",
        );
      });
    });
  });

  group('Cross-platform Crashlytics configuration consistency', () {
    test('both Android and iOS Crashlytics configuration files exist', () {
      expect(
        File(projectPath('android/settings.gradle.kts')).existsSync(),
        isTrue,
        reason: 'android/settings.gradle.kts must exist',
      );
      expect(
        File(projectPath('android/app/build.gradle.kts')).existsSync(),
        isTrue,
        reason: 'android/app/build.gradle.kts must exist',
      );
      expect(
        File(projectPath('ios/Podfile')).existsSync(),
        isTrue,
        reason: 'ios/Podfile must exist',
      );
    });

    test(
        'Android GMS google-services plugin co-exists with Crashlytics plugin in settings',
        () {
      final settingsContent =
          File(projectPath('android/settings.gradle.kts')).readAsStringSync();
      // Crashlytics requires google-services; both must be declared.
      expect(
        settingsContent,
        contains('com.google.gms.google-services'),
        reason:
            'google-services plugin must remain declared alongside Crashlytics',
      );
      expect(
        settingsContent,
        contains('com.google.firebase.crashlytics'),
        reason: 'Crashlytics plugin must be declared in settings',
      );
    });

    test(
        'Android GMS google-services plugin co-exists with Crashlytics plugin in app build',
        () {
      final appBuildContent =
          File(projectPath('android/app/build.gradle.kts')).readAsStringSync();
      expect(
        appBuildContent,
        contains('com.google.gms.google-services'),
        reason:
            'google-services plugin must be applied alongside Crashlytics in app build',
      );
      expect(
        appBuildContent,
        contains('com.google.firebase.crashlytics'),
        reason: 'Crashlytics plugin must be applied in app build',
      );
    });
  });
}