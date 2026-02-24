import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentStorageService service;
  late Directory tempDir;
  late Directory appDocDir;
  late File secretFile;

  setUp(() async {
    // Create a temporary directory for tests
    tempDir = Directory.systemTemp.createTempSync('inv_tracker_security_test_');
    appDocDir = Directory(path.join(tempDir.path, 'app_docs'));
    await appDocDir.create();

    // Create a sensitive file outside the app documents directory
    secretFile = File(path.join(tempDir.path, 'secret.txt'));
    await secretFile.writeAsString('SENSITIVE_DATA');

    // Mock path_provider channel
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return appDocDir.path;
        }
        return null;
      },
    );

    service = DocumentStorageService(userId: 'test_user');
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  test('SECURITY CHECK: readDocument prevents reading files outside allowed directory', () async {
    // Attempt to read the secret file using absolute path
    // This simulates a path traversal attack where the attacker supplies an absolute path
    final result = await service.readDocument(secretFile.path);

    // If result is null, it means the file access was blocked (SECURITY FIXED)
    expect(result, isNull);
  });
}
