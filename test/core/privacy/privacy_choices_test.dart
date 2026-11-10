import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/privacy/privacy_choices.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApplier implements PrivacyCollectionApplier {
  final List<String> calls = [];

  @override
  Future<void> setAnalytics(bool enabled) async =>
      calls.add('analytics:$enabled');

  @override
  Future<void> setPerformance(bool enabled) async =>
      calls.add('performance:$enabled');

  @override
  Future<void> setCrashReports(bool enabled) async =>
      calls.add('crash:$enabled');
}

Future<(ProviderContainer, _FakeApplier, SharedPreferences)> _setup([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final applier = _FakeApplier();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      privacyCollectionApplierProvider.overrideWithValue(applier),
    ],
  );
  addTearDown(container.dispose);
  return (container, applier, prefs);
}

/// A preferences store whose writes fail.
class _FailingPrefs implements SharedPreferences {
  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async =>
      throw StateError('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('when the save fails', () {
    test(
      'turning crash reports off puts the Crashlytics setting back',
      () async {
        final applier = _FakeApplier();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_FailingPrefs()),
            privacyCollectionApplierProvider.overrideWithValue(applier),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(crashReportsProvider.notifier).setEnabled(false),
          throwsStateError,
        );
        expect(applier.calls, ['crash:false', 'crash:true']);
        expect(container.read(crashReportsProvider), isTrue);
      },
    );

    test(
      'turning usage data off puts analytics and performance back',
      () async {
        final applier = _FakeApplier();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_FailingPrefs()),
            privacyCollectionApplierProvider.overrideWithValue(applier),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(analyticsSharingProvider.notifier).setEnabled(false),
          throwsStateError,
        );
        expect(applier.calls, [
          'analytics:false',
          'performance:false',
          'analytics:true',
          'performance:true',
        ]);
        expect(container.read(analyticsSharingProvider), isTrue);
      },
    );
  });

  group('defaults', () {
    test('both choices are on when nothing was saved', () async {
      final (container, _, _) = await _setup();
      expect(container.read(analyticsSharingProvider), isTrue);
      expect(container.read(crashReportsProvider), isTrue);
    });
  });

  group('switching off', () {
    test(
      'analytics off is saved and also stops performance monitoring',
      () async {
        final (container, applier, prefs) = await _setup();
        await container
            .read(analyticsSharingProvider.notifier)
            .setEnabled(false);

        expect(container.read(analyticsSharingProvider), isFalse);
        expect(prefs.getBool(privacyAnalyticsKey), isFalse);
        expect(applier.calls, ['analytics:false', 'performance:false']);
        expect(container.read(crashReportsProvider), isTrue);
      },
    );

    test('crash reports off is saved and applied', () async {
      final (container, applier, prefs) = await _setup();
      await container.read(crashReportsProvider.notifier).setEnabled(false);

      expect(container.read(crashReportsProvider), isFalse);
      expect(prefs.getBool(privacyCrashReportsKey), isFalse);
      expect(applier.calls, ['crash:false']);
    });

    test('switching back on applies true', () async {
      final (container, applier, _) = await _setup({
        privacyAnalyticsKey: false,
      });
      await container.read(analyticsSharingProvider.notifier).setEnabled(true);

      expect(container.read(analyticsSharingProvider), isTrue);
      expect(applier.calls, ['analytics:true', 'performance:true']);
    });

    test(
      'analytics goes back to its old value if a later step fails',
      () async {
        final (_, _, prefs) = await _setup();
        final applier = _FailsOnPerformanceApplier();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            privacyCollectionApplierProvider.overrideWithValue(applier),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(analyticsSharingProvider.notifier).setEnabled(false),
          throwsA(isA<StateError>()),
        );
        expect(applier.calls, ['analytics:false', 'analytics:true']);
        expect(prefs.containsKey(privacyAnalyticsKey), isFalse);
        expect(container.read(analyticsSharingProvider), isTrue);
      },
    );

    test('nothing is saved when applying to Firebase fails', () async {
      final (container, applier, prefs) = await _setup();
      final failing = _ThrowingApplier();
      final failingContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          privacyCollectionApplierProvider.overrideWithValue(failing),
        ],
      );
      addTearDown(failingContainer.dispose);

      await expectLater(
        failingContainer.read(crashReportsProvider.notifier).setEnabled(false),
        throwsA(isA<StateError>()),
      );
      expect(prefs.containsKey(privacyCrashReportsKey), isFalse);
      expect(failingContainer.read(crashReportsProvider), isTrue);
      expect(applier.calls, isEmpty);
      expect(container.read(crashReportsProvider), isTrue);
    });
  });

  group('app start', () {
    test(
      'saved off choices are applied before anything is collected',
      () async {
        final (_, applier, prefs) = await _setup({
          privacyAnalyticsKey: false,
          privacyCrashReportsKey: false,
        });
        await applyStoredPrivacyChoices(prefs, applier);

        expect(applier.calls, [
          'analytics:false',
          'performance:false',
          'crash:false',
        ]);
      },
    );

    test('one failing setting does not stop the others', () async {
      final (_, _, prefs) = await _setup({privacyCrashReportsKey: false});
      final applier = _FailsOnAnalyticsApplier();
      await applyStoredPrivacyChoices(prefs, applier);

      expect(applier.calls, ['performance:true', 'crash:false']);
    });

    test('with nothing saved, start-up keeps collection on', () async {
      final (_, applier, prefs) = await _setup();
      await applyStoredPrivacyChoices(prefs, applier);

      expect(applier.calls, [
        'analytics:true',
        'performance:true',
        'crash:true',
      ]);
    });
  });

  group('crashCollectionEnabled', () {
    test('user off always wins', () {
      expect(
        crashCollectionEnabled(
          userChoice: false,
          debugModeEnabled: true,
          isDebugBuild: false,
        ),
        isFalse,
      );
    });

    test('release build follows the user choice', () {
      expect(
        crashCollectionEnabled(
          userChoice: true,
          debugModeEnabled: false,
          isDebugBuild: false,
        ),
        isTrue,
      );
    });

    test('debug build needs the debug-mode switch as well', () {
      expect(
        crashCollectionEnabled(
          userChoice: true,
          debugModeEnabled: false,
          isDebugBuild: true,
        ),
        isFalse,
      );
      expect(
        crashCollectionEnabled(
          userChoice: true,
          debugModeEnabled: true,
          isDebugBuild: true,
        ),
        isTrue,
      );
    });
  });
}

class _ThrowingApplier implements PrivacyCollectionApplier {
  @override
  Future<void> setAnalytics(bool enabled) async => throw StateError('x');

  @override
  Future<void> setPerformance(bool enabled) async => throw StateError('x');

  @override
  Future<void> setCrashReports(bool enabled) async => throw StateError('x');
}

class _FailsOnPerformanceApplier implements PrivacyCollectionApplier {
  final List<String> calls = [];

  @override
  Future<void> setAnalytics(bool enabled) async =>
      calls.add('analytics:$enabled');

  @override
  Future<void> setPerformance(bool enabled) async => throw StateError('x');

  @override
  Future<void> setCrashReports(bool enabled) async {}
}

class _FailsOnAnalyticsApplier implements PrivacyCollectionApplier {
  final List<String> calls = [];

  @override
  Future<void> setAnalytics(bool enabled) async => throw StateError('x');

  @override
  Future<void> setPerformance(bool enabled) async =>
      calls.add('performance:$enabled');

  @override
  Future<void> setCrashReports(bool enabled) async =>
      calls.add('crash:$enabled');
}
