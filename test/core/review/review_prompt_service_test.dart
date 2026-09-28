import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/review/review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_analytics_service.dart';

class FakeReviewLauncher implements ReviewLauncher {
  FakeReviewLauncher({this.available = true, this.throwOnRequest = false});

  final bool available;
  final bool throwOnRequest;
  int isAvailableCalls = 0;
  int requestReviewCalls = 0;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (throwOnRequest) {
      throw Exception('launcher failure');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAnalyticsService fakeAnalytics;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
  });

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  ReviewPromptService buildServiceFor(
    SharedPreferences prefs, {
    required ReviewLauncher launcher,
    bool isSupportedPlatform = true,
    bool Function() isUpdatePending = _never,
  }) {
    return ReviewPromptService(
      prefs: prefs,
      launcher: launcher,
      analytics: fakeAnalytics,
      isUpdatePending: isUpdatePending,
      isSupportedPlatform: () => isSupportedPlatform,
    );
  }

  Future<ReviewPromptService> buildService({
    required ReviewLauncher launcher,
    bool isSupportedPlatform = true,
    bool Function() isUpdatePending = _never,
  }) async {
    final prefs = await freshPrefs();
    return buildServiceFor(
      prefs,
      launcher: launcher,
      isSupportedPlatform: isSupportedPlatform,
      isUpdatePending: isUpdatePending,
    );
  }

  group('ReviewPromptService', () {
    test('first exit requests exactly once', () async {
      final launcher = FakeReviewLauncher();
      final service = await buildService(launcher: launcher);

      await service.maybeRequestAfterExitRecorded();

      expect(launcher.requestReviewCalls, 1);
      expect(fakeAnalytics.loggedEvents, hasLength(1));
      expect(fakeAnalytics.loggedEvents.single.name, 'review_prompt_requested');
      expect(fakeAnalytics.loggedEvents.single.parameters, isNull);
    });

    test('a second exit does not request again', () async {
      final launcher = FakeReviewLauncher();
      final service = await buildService(launcher: launcher);

      await service.maybeRequestAfterExitRecorded();
      await service.maybeRequestAfterExitRecorded();

      expect(launcher.requestReviewCalls, 1);
      expect(fakeAnalytics.loggedEvents, hasLength(1));
    });

    test('non-Android is a no-op', () async {
      final launcher = FakeReviewLauncher();
      final service = await buildService(
        launcher: launcher,
        isSupportedPlatform: false,
      );

      await service.maybeRequestAfterExitRecorded();

      expect(launcher.isAvailableCalls, 0);
      expect(launcher.requestReviewCalls, 0);
      expect(fakeAnalytics.loggedEvents, isEmpty);
    });

    test('a pending in-app update suppresses without spending the shot', () async {
      final launcher = FakeReviewLauncher();
      var updatePending = true;
      final service = await buildService(
        launcher: launcher,
        isUpdatePending: () => updatePending,
      );

      await service.maybeRequestAfterExitRecorded();
      expect(launcher.requestReviewCalls, 0);

      updatePending = false;
      await service.maybeRequestAfterExitRecorded();
      expect(launcher.requestReviewCalls, 1);
    });

    test('launcher unavailable does not spend the one shot', () async {
      final prefs = await freshPrefs();
      final unavailableLauncher = FakeReviewLauncher(available: false);
      await buildServiceFor(
        prefs,
        launcher: unavailableLauncher,
      ).maybeRequestAfterExitRecorded();

      expect(unavailableLauncher.requestReviewCalls, 0);
      expect(fakeAnalytics.loggedEvents, isEmpty);

      // Same install (same prefs), a later exit where availability recovers:
      // the shot is still there to spend.
      final recoveredLauncher = FakeReviewLauncher();
      await buildServiceFor(
        prefs,
        launcher: recoveredLauncher,
      ).maybeRequestAfterExitRecorded();

      expect(recoveredLauncher.requestReviewCalls, 1);
    });

    test('a throwing launcher cannot propagate to the caller', () async {
      final launcher = FakeReviewLauncher(throwOnRequest: true);
      final service = await buildService(launcher: launcher);

      await expectLater(
        service.maybeRequestAfterExitRecorded(),
        completes,
      );
      expect(launcher.requestReviewCalls, 1);
    });

    test('overlapping calls only request once', () async {
      final launcher = FakeReviewLauncher();
      final service = await buildService(launcher: launcher);

      await Future.wait([
        service.maybeRequestAfterExitRecorded(),
        service.maybeRequestAfterExitRecorded(),
      ]);

      expect(launcher.requestReviewCalls, 1);
    });
  });
}

bool _never() => false;
