import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InAppUpdateService service;
  late MethodChannel channel;

  setUp(() {
    service = InAppUpdateService();
    channel = const MethodChannel('de.ffuf.in_app_update/methods');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('checkForUpdate', () {
    test('returns null when PlatformException is thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkForUpdate') {
          throw PlatformException(code: 'TASK_FAILURE', message: 'Install Error(-9)');
        }
        return null;
      });

      final result = await service.checkForUpdate();
      expect(result, isNull);
    });

    test('returns AppUpdateInfo when successful', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkForUpdate') {
          return {
            'updateAvailability': 2, // updateAvailable
            'immediateAllowed': true,
            'flexibleAllowed': true,
            'availableVersionCode': 100,
            'installStatus': 0,
            'packageName': 'com.test.app',
            'clientVersionStalenessDays': 5,
            'updatePriority': 4,
          };
        }
        return null;
      });

      final result = await service.checkForUpdate();
      expect(result, isNotNull);
      expect(result?.updateAvailability, UpdateAvailability.updateAvailable);
    });
  });

  group('startImmediateUpdate', () {
    test('returns inAppUpdateFailed when PlatformException is thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'performImmediateUpdate') {
          throw PlatformException(code: 'TASK_FAILURE', message: 'Install Error(-6)');
        }
        return null;
      });

      final result = await service.startImmediateUpdate();
      expect(result, AppUpdateResult.inAppUpdateFailed);
    });
  });

  group('startFlexibleUpdate', () {
    test('returns inAppUpdateFailed when PlatformException is thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'startFlexibleUpdate') {
          throw PlatformException(code: 'TASK_FAILURE', message: 'Install Error(-6)');
        }
        return null;
      });

      final result = await service.startFlexibleUpdate();
      expect(result, AppUpdateResult.inAppUpdateFailed);
    });
  });

  group('completeFlexibleUpdate', () {
    test('completes normally when PlatformException is thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'completeFlexibleUpdate') {
          throw PlatformException(code: 'TASK_FAILURE', message: 'Install Error(-6)');
        }
        return null;
      });

      await expectLater(service.completeFlexibleUpdate(), completes);
    });
  });
}
