import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentStorageService service;
  late String mockAppDocPath;
  late Directory tempDir;
  late File sensitiveFile;
  late File validFile;

  setUp(() async {
    // Create a temporary directory for tests
    tempDir = Directory.systemTemp.createTempSync('inv_tracker_test_');
    mockAppDocPath = tempDir.path;

    // Create a "sensitive" file OUTSIDE the allowed documents directory
    // We simulate this by putting it directly in tempDir, while documents are in tempDir/documents
    // Actually, DocumentStorageService allows everything in getApplicationDocumentsDirectory (tempDir).
    // So to simulate traversal, we need a file OUTSIDE tempDir.
    // But on many systems we can't write outside temp.
    // So we need to trick the mock.

    // Strategy:
    // 1. mockAppDocPath = tempDir/allowed
    // 2. sensitiveFile = tempDir/sensitive.txt
    // 3. service checks if path is within mockAppDocPath (tempDir/allowed)
    // 4. We try to read sensitiveFile.path (which is outside tempDir/allowed)

    final allowedDir = Directory('${tempDir.path}/allowed');
    allowedDir.createSync();
    mockAppDocPath = allowedDir.path;

    sensitiveFile = File('${tempDir.path}/sensitive.txt');
    await sensitiveFile.writeAsString('SENSITIVE_DATA');

    // Create a valid file inside allowed dir
    final validDir = Directory('${allowedDir.path}/documents/test_user/inv_1');
    validDir.createSync(recursive: true);
    validFile = File('${validDir.path}/valid.txt');
    await validFile.writeAsString('VALID_DATA');

    // Mock path_provider channel
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return mockAppDocPath;
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

  test('readDocument PREVENTS path traversal to sensitive file', () async {
    // Attempt to read file outside of mockAppDocPath
    final bytes = await service.readDocument(sensitiveFile.path);

    // Should be null because it's outside the allowed directory
    expect(bytes, isNull, reason: 'Should prevent reading sensitive file outside allowed directory');
  });

  test('readDocument ALLOWS reading valid file', () async {
    // Attempt to read file inside mockAppDocPath
    final bytes = await service.readDocument(validFile.path);

    expect(bytes, isNotNull, reason: 'Should allow reading valid file');
    final content = String.fromCharCodes(bytes!);
    expect(content, equals('VALID_DATA'));
  });

  test('documentExists returns false for unsafe path', () async {
    final exists = await service.documentExists(sensitiveFile.path);
    expect(exists, isFalse);
  });

  test('deleteDocument ignores unsafe path', () async {
    // Ensure file exists first
    expect(sensitiveFile.existsSync(), isTrue);

    await service.deleteDocument(sensitiveFile.path);

    // File should still exist
    expect(sensitiveFile.existsSync(), isTrue);
  });

  test('getFileSize returns 0 for unsafe path', () async {
    final size = await service.getFileSize(sensitiveFile.path);
    expect(size, equals(0));
  });
}
