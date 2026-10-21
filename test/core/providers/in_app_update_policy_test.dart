import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUpdateInfo _info({int? staleness}) => AppUpdateInfo(
  updateAvailability: UpdateAvailability.updateAvailable,
  immediateUpdateAllowed: true,
  flexibleUpdateAllowed: true,
  availableVersionCode: 2,
  installStatus: InstallStatus.unknown,
  packageName: 'com.example',
  clientVersionStalenessDays: staleness,
  updatePriority: 5,
  immediateAllowedPreconditions: [],
  flexibleAllowedPreconditions: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('InAppUpdateState.isStale (GAP3-08)', () {
    test('false below 60 days, even at the highest Play priority', () {
      expect(
        InAppUpdateState(updateInfo: _info(staleness: 59)).isStale,
        isFalse,
      );
    });

    test('true at exactly 60 days', () {
      expect(
        InAppUpdateState(updateInfo: _info(staleness: 60)).isStale,
        isTrue,
      );
    });

    test('false when Play reports no staleness or no update info', () {
      expect(InAppUpdateState(updateInfo: _info()).isStale, isFalse);
      expect(const InAppUpdateState().isStale, isFalse);
    });
  });

  group('update prompt throttle (GAP3-08)', () {
    final now = DateTime(2026, 10, 21, 12);

    Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('prompts when it has never prompted', () async {
      final c = await containerWith({});
      expect(c.read(inAppUpdateProvider.notifier).shouldPromptNow(now), isTrue);
    });

    test('does not prompt again within 3 days of the last prompt', () async {
      final c = await containerWith({});
      final n = c.read(inAppUpdateProvider.notifier);
      await n.markPrompted(now);
      expect(
        n.shouldPromptNow(now.add(const Duration(days: 2, hours: 23))),
        isFalse,
      );
    });

    test('prompts again once 3 days have passed', () async {
      final c = await containerWith({});
      final n = c.read(inAppUpdateProvider.notifier);
      await n.markPrompted(now);
      expect(n.shouldPromptNow(now.add(const Duration(days: 3))), isTrue);
    });
  });
}
